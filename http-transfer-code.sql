-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('http-transfer-code.sql', '$Id');

-- Wicci abstractions for http requests and replies

-- ** Copyright

-- Copyright (c) 2005-2015, J. Greg Davidson.
-- You may use this file under the terms of the
-- GNU AFFERO GENERAL PUBLIC LICENSE 3.0
-- as specified in the file LICENSE.md included with this distribution.
-- All other use requires my permission in writing.

-- * http_request functions


-- ** UTF8 <-> LATIN1 conversion

CREATE OR REPLACE FUNCTION latin1(text) RETURNS bytea AS $$
	SELECT convert_to($1, 'LATIN1')
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION latin1(text)
IS 'Convert text (probably UTF8 encoded) to LATIN1 encoded bytea';

CREATE OR REPLACE FUNCTION latin1(bytea) RETURNS text AS $$
	SELECT convert_from($1, 'LATIN1')
$$ LANGUAGE sql STRICT;

COMMENT ON FUNCTION latin1(bytea)
IS 'Convert bytea to text (presumably UTF8 encoded);
We are assuming that the bytea IS latin1 encoded text!!';

-- ** type http_request_refs methods

CREATE OR REPLACE FUNCTION http_requests(
	http_request_refs[], http_request_name_refs
) RETURNS SETOF http_request_refs AS $$
  SELECT ref FROM http_request_rows
	WHERE ref = ANY($1) AND name_ = $2
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION http_request_values(
	http_request_refs[], http_request_name_refs
) RETURNS SETOF text AS $$
  SELECT value_ FROM http_request_rows
	WHERE ref = ANY($1) AND name_ = $2
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION http_request_value(
	http_request_refs[], http_request_name_refs
) RETURNS text AS $$
  SELECT http_request_values($1, $2) LIMIT 1
$$ LANGUAGE SQL;

DROP OPERATOR IF EXISTS
	^ (http_request_refs[], http_request_name_refs) CASCADE;

CREATE OPERATOR ^ (
		leftarg = http_request_refs[],
		rightarg = http_request_name_refs,
		procedure = http_request_value
);

/*
CREATE OR REPLACE
FUNCTION http_small_request_text(http_request_refs)
RETURNS text AS $$
  SELECT CASE
		WHEN name_ = http_request_name_nil() THEN ''
		ELSE http_request_name_text(name_) || ': '
	END || value_ FROM http_small_request_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_big_request_text(http_request_refs)
RETURNS text AS $$
  SELECT CASE
		WHEN name_ = http_request_name_nil() THEN ''
		ELSE http_request_name_text(name_) || ': '
	END || value_ FROM http_big_request_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_request_text(http_request_refs)
RETURNS text AS $$
  SELECT CASE ref_table($1)
		WHEN 'http_small_request_rows'::regclass THEN http_small_request_text($1)
		WHEN 'http_big_request_rows'::regclass THEN http_big_request_text($1)
	END
$$ LANGUAGE SQL;
*/

CREATE OR REPLACE
FUNCTION http_request_text(http_request_refs)
RETURNS text AS $$
  SELECT CASE
		WHEN name_ = http_request_name_nil() THEN ''
		ELSE http_request_name_text(name_) || ': '
	END || value_ FROM http_request_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_requests_text(http_request_refs[])
RETURNS text  AS $$
	SELECT array_to_string( texts, E'\n' )
	|| CASE WHEN array_is_empty(texts) THEN '' ELSE E'\n' END
	FROM
	( SELECT ARRAY( SELECT http_request_text(x) FROM unnest($1) x ) ) foo(texts)
$$ LANGUAGE sql;

COMMENT ON FUNCTION http_requests_text(http_request_refs[])
IS 'show each request as \\n-terminated line';

/*
CREATE OR REPLACE
FUNCTION try_small_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
  SELECT ref FROM http_small_request_rows
	WHERE name_ = $1 AND value_ = $2
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_big_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
  SELECT ref FROM http_big_request_rows
	WHERE name_ = $1 AND hash_ = hash($2)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
  SELECT COALESCE( try_small_http_request($1, $2), try_big_http_request($1, $2) )
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
  SELECT non_null(
		COALESCE( try_small_http_request($1, $2), try_big_http_request($1, $2) ),
		'find_http_request(http_request_name_refs, text)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
DECLARE
	maybe http_request_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure := 'get_http_request(http_request_name_refs, text)';
	big BOOLEAN := octet_length($2) > max_indexable_field_size();
BEGIN
	LOOP
		maybe := try_http_request($1, $2);
		IF maybe IS NOT NULL THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		BEGIN
			IF big THEN
			 INSERT INTO http_big_request_rows(name_, value_, hash_)
			 VALUES ($1, $2, hash($2));
		ELSE
			 INSERT INTO http_small_request_rows(name_, value_)
			 VALUES ($1, $2);
		END IF;
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;
*/

CREATE OR REPLACE
FUNCTION try_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
  SELECT ref FROM http_request_rows
	WHERE name_ = $1 AND value_ = $2
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION find_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
  SELECT non_null(
		try_http_request($1, $2), 'find_http_request(http_request_name_refs, text)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
DECLARE
	maybe http_request_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure := 'get_http_request(http_request_name_refs, text)';
BEGIN
	LOOP
		maybe := try_http_request($1, $2);
		IF maybe IS NOT NULL THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		BEGIN
			 INSERT INTO http_request_rows(name_, value_)
			 VALUES ($1, $2);
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION get_http_request(http_request_name_refs, text)
RETURNS http_request_refs AS $$
	SELECT non_null(
		try_get_http_request($1, $2), 'get_http_request(http_request_name_refs, text)'
  )
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION get_http_request_(citext, text)
RETURNS http_request_refs AS $$
  SELECT CASE
		WHEN non_nil(_name) THEN get_http_request(_name, _value)
		ELSE get_http_request(
			http_request_name_nil(), COALESCE($1::text, '') || ': ' || _value
		)
	END FROM
		try_http_request_name($1) _name,
		COALESCE(str_trim($2), '') _value
$$ LANGUAGE SQL;

-- changed space+ to space* 2012-7-9 jgd!!
CREATE OR REPLACE
FUNCTION try_get_http_request(text)
RETURNS http_request_refs AS $$
  SELECT get_http_request_(name_value[1]::citext, name_value[2])
	FROM try_str_match($1, '^([^:]+):[[:space:]]*(.*)$') name_value
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_http_request(text)
RETURNS http_request_refs AS $$
	SELECT non_null(
		try_get_http_request($1), 'get_http_request(text)'
  )
$$ LANGUAGE SQL;

-- ** http_request_refs classes declarations

SELECT type_class_op_method(
	'http_request_refs', 'http_request_rows',
	'ref_text_op(refs)', 'http_request_text(http_request_refs)'
);

/*
SELECT type_class_op_method(
	'http_request_refs', 'http_small_request_rows',
	'ref_text_op(refs)', 'http_small_request_text(http_request_refs)'
);

SELECT type_class_op_method(
	'http_request_refs', 'http_big_request_rows',
	'ref_text_op(refs)', 'http_big_request_text(http_request_refs)'
);
*/

-- ** parsing http_transfers

CREATE OR REPLACE
FUNCTION try_first_http_requests(text)
RETURNS http_request_refs[] AS $$
	SELECT CASE
	WHEN $1 ~ '^[^:]+:[[:space:]]' THEN
		ARRAY[get_http_request($1)]
	ELSE ( SELECT
		CASE array_length(fields)
			WHEN 1 THEN  ARRAY[
				get_http_request(http_request_name_type(), 'GET'),
				get_http_request(http_request_name_url(), fields[1])
			]
			WHEN 2 THEN ARRAY[
				get_http_request(http_request_name_type(), fields[1]),
				get_http_request(http_request_name_url(), fields[2])
			]
			WHEN 3 THEN ARRAY[
				get_http_request(http_request_name_type(), fields[1]),
				get_http_request(http_request_name_url(), fields[2]),
				get_http_request(http_request_name_protocol(), fields[3])
			]
			ELSE NULL
		END
		FROM string_to_array($1, ' ') fields --  allow arbitrary whitespace ???
	) END
$$ LANGUAGE SQL STRICT;
COMMENT ON FUNCTION try_first_http_requests(text) IS
'Converts 1st line of a http_transfer into headers.  Handles
(1) Naked path
(2) request url optional-protocol
(3) a regular "name: value" header line
';

CREATE OR REPLACE
FUNCTION first_http_requests(text)
RETURNS http_request_refs[] AS $$
	SELECT non_null(
		try_first_http_requests($1),
		'first_http_requests(text)'
  )
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_headers_lines(text) RETURNS text[] AS $$
	SELECT string_to_array(str_trim_right(regexp_replace($1, E'\n\t+', '', 'g')), E'\n') lines
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_headers(text)
RETURNS http_request_refs[] AS $$
  SELECT first_http_requests(str_trim(lines[1])) || ARRAY(
	  SELECT get_http_request(str_trim(line))
		FROM unnest(lines[2:array_length(lines)]) line
	) FROM http_headers_lines($1) lines
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_parse_http_requests(bytea) 
RETURNS http_request_refs[] AS $$
	SELECT http_headers( headers_text ) FROM
		regexp_replace(latin1($1), E'\r', '', 'g') headers_text,
		debug_enter('try_parse_http_requests(bytea)', latin1($1))
	WHERE headers_text IS NOT NULL
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION parse_http_requests(bytea)
RETURNS http_request_refs[] AS $$
	SELECT non_null(
		try_parse_http_requests($1),
		'parse_http_requests(bytea)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_get_http_requests_url(http_request_refs[]) 
RETURNS uri_refs AS $$
	SELECT try_get_uri( COALESCE($1^'host', '') || regexp_replace($1^'_url', '^/*', '/') )
$$ LANGUAGE SQL STRICT;

-- CREATE OR REPLACE
-- FUNCTION try_get_http_requests_cookie(http_request_refs[]) 
-- RETURNS uri_query_refs AS $$
-- 	SELECT try_uri_query( $1^'Cookie' )
-- $$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION get_http_requests_cookies(http_request_refs[]) 
RETURNS uri_query_refs AS $$
	SELECT COALESCE( try_uri_query( $1^'Cookie' ), uri_query_nil() )
$$ LANGUAGE SQL STRICT;

COMMENT ON FUNCTION 
get_http_requests_cookies(http_request_refs[])
IS 'Returns a reference to the uri_query representing any queries
or a reference to uri_query_nil whose row has no query elements';

CREATE OR REPLACE
FUNCTION get_http_requests_url(http_request_refs[])
RETURNS uri_refs AS $$
	SELECT non_null(
		try_get_http_requests_url($1),
		'get_http_requests_url(http_request_refs[])', http_requests_text($1)
	)
$$ LANGUAGE SQL;

-- * http_response functions

-- ** type http_response_refs methods

-- WHY WOULD THIS EXIST??
-- CREATE OR REPLACE FUNCTION try_http_response(
-- 	http_response_refs, http_response_name_refs
-- ) RETURNS http_response_refs AS $$
--   SELECT $1 FROM http_response_rows
-- 	WHERE ref = $1 AND name_ = $2
-- $$ LANGUAGE SQL STRICT;

CREATE OR REPLACE FUNCTION http_responses(
	http_response_refs[], http_response_name_refs
) RETURNS SETOF http_response_refs AS $$
  SELECT ref FROM http_response_rows
	WHERE ref = ANY($1) AND name_ = $2
$$ LANGUAGE SQL;

/* IS THIS NEEDED?  DID WE WANT TEXT OR WHAT?
CREATE OR REPLACE FUNCTION http_response_values(
	http_response_refs[], http_response_name_refs
) RETURNS SETOF text AS $$
  SELECT value_ FROM http_response_rows
	WHERE ref = ANY($1) AND name_ = $2
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION http_response_value(
	http_response_refs[], http_response_name_refs
) RETURNS text AS $$
  SELECT http_response_values($1, $2) LIMIT 1
$$ LANGUAGE SQL;
*/

DROP OPERATOR IF EXISTS
	^ (http_response_refs[], http_response_name_refs) CASCADE;

CREATE OPERATOR ^ (
		leftarg = http_response_refs[],
		rightarg = http_response_name_refs,
--		procedure = http_response_value
		procedure = http_responses
);

CREATE OR REPLACE
FUNCTION http_small_response_text(http_response_refs)
RETURNS text AS $$
  SELECT http_response_name_text(name_) || ': ' || text_value
	FROM http_small_text_response_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_big_response_text(http_response_refs)
RETURNS text AS $$
  SELECT http_response_name_text(name_) || ':big: ' || md5(text_value)
	FROM http_big_text_response_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_binary_response_text(http_response_refs)
RETURNS text AS $$
  SELECT http_response_name_text(name_) || ':binary: ' || md5(binary_value)
	FROM http_binary_response_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_response_text(http_response_refs)
RETURNS text AS $$
  SELECT COALESCE(
		http_small_response_text($1),
		http_big_response_text($1),
		http_binary_response_text($1)
	)
$$ LANGUAGE SQL;

/*
CREATE OR REPLACE
FUNCTION http_response_text(http_response_refs)
RETURNS text AS $$
  SELECT CASE
		WHEN is_nil(name_) THEN ''
		ELSE http_response_name_text(name_) || ': '
	END || value_ FROM http_response_rows WHERE ref = $1
$$ LANGUAGE SQL;
*/

CREATE OR REPLACE
FUNCTION http_responses_text(http_response_refs[])
RETURNS text  AS $$
	SELECT array_to_string( ARRAY(
		SELECT http_response_text(x) FROM unnest($1) x
	), E'\n' )
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_http_small_text_response(http_response_name_refs, text)
RETURNS http_response_refs AS $$
  SELECT ref FROM http_small_text_response_rows
	WHERE name_ = $1 AND text_value = $2
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_http_big_text_response(http_response_name_refs, text)
RETURNS http_response_refs AS $$
  SELECT ref FROM http_big_text_response_rows
	WHERE name_ = $1 AND hash_ = hash($2)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_http_binary_response(http_response_name_refs, bytea)
RETURNS http_response_refs AS $$
  SELECT ref FROM http_binary_response_rows
	WHERE name_ = $1 AND hash_ = hash($2)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_http_text_response(http_response_name_refs, text)
RETURNS http_response_refs AS $$
  SELECT COALESCE(
		try_http_small_text_response($1, $2),
		try_http_big_text_response($1, $2)
	)
$$ LANGUAGE SQL;

/* NOT NEEDED??
CREATE OR REPLACE
FUNCTION find_http_response(http_response_name_refs, text)
RETURNS http_response_refs AS $$
  SELECT non_null(
		try_http_response($1, $2),
		'find_http_response(http_response_name_refs, text)'
	)
$$ LANGUAGE SQL;
*/

CREATE OR REPLACE
FUNCTION try_get_text_response(http_response_name_refs, _text_ text)
RETURNS http_response_refs AS $$
DECLARE
	maybe http_response_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'try_get_text_response(http_response_name_refs, text)';
	big BOOLEAN := octet_length($2) > max_indexable_field_size();
BEGIN
	LOOP
		maybe := try_http_text_response($1, $2);
		IF maybe IS NOT NULL THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		kilroy_was_here := true;
		BEGIN
			IF big THEN
				INSERT INTO http_big_text_response_rows(name_, text_value, hash_)
				VALUES ($1, $2, hash($2));
			ELSE
				INSERT INTO http_small_text_response_rows(name_, text_value)
				VALUES ($1, $2);
			END IF;
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE
FUNCTION try_get_binary_response(http_response_name_refs, bytea)
RETURNS http_response_refs AS $$
DECLARE
	maybe http_response_refs := NULL; -- unchecked_ref_null();
	kilroy_was_here boolean := false;
	this regprocedure
		:= 'try_get_binary_response(http_response_name_refs, bytea)';
BEGIN
	LOOP
		maybe := try_http_binary_response($1, $2);
		IF maybe IS NOT NULL THEN RETURN maybe; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % % bytes', this, $1, octet_length($2);
		END IF;
		kilroy_was_here := true;
		BEGIN
			INSERT INTO http_binary_response_rows(name_, binary_value, hash_)
			VALUES ($1, $2, hash($2));
		EXCEPTION
			WHEN unique_violation THEN			-- another thread??
				RAISE NOTICE '% % % bytes raised %!', this, $1, octet_length($2), 'unique_violation';
		END;	
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION get_http_text_response(
	http_response_name_refs, _text_ text
) RETURNS http_response_refs AS $$
	SELECT non_null(
		try_get_text_response($1,$2),
		'get_http_text_response(http_response_name_refs,text)',
		$1::text, $2
	)
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION get_http_binary_response(
	http_response_name_refs, _bytes_ bytea = NULL
) RETURNS http_response_refs AS $$
	SELECT non_null(
		try_get_binary_response(
			non_null($1, this, http_response_name_text($1)),
			non_null($2, this, octet_length($2)::text, 'binary bytes')
		), this,	$1::text, octet_length($2)::text, 'binary bytes'
	) FROM
	COALESCE('get_http_binary_response(http_response_name_refs,bytea)'::regprocedure) this
$$ LANGUAGE sql;

CREATE OR REPLACE VIEW http_cookie_names(name_) AS
VALUES ( 'user'::text ), ( 'session');

COMMENT ON  VIEW http_cookie_names IS
'List of cookies I may allow - currently not used!!';

CREATE OR REPLACE
FUNCTION http_cookie_time(timestamp with time zone)
RETURNS text AS $$
  SELECT to_char(timezone('UTC', $1), 'Dy, DD-Mon-YYYY HH24:MI:SS GMT');
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_format_http_cookie_text(a text[]) RETURNS text AS $$
	SELECT array_to_string(	ARRAY(
		SELECT a[i] || '=' || a[i+1]
		FROM generate_series(1, _len, 2) i
	), '; '
	) FROM array_length($1) _len
	WHERE _len > 0 AND _len % 2 = 0
$$ LANGUAGE sql;

CREATE OR REPLACE
FUNCTION try_http_cookie_text(
	_expires timestamp with time zone = CURRENT_TIMESTAMP,
	_interval interval = '1 year',
	_url uri_refs = uri_nil(),
	_pairs text[] = NULL
) RETURNS text AS $$
  SELECT try_format_http_cookie_text(
		_pairs || ARRAY[
			'expires', http_cookie_time(_expires + _interval),
			'path',  path_::text,
  		'domain', domain_::text
		]
	) FROM page_uri_rows WHERE ref = try_page_uri(_url)
$$ LANGUAGE sql;

COMMENT ON FUNCTION try_http_cookie_text(
	_expires timestamp with time zone,	_interval interval,
	_url uri_refs,	_pairs text[]
) IS $$
RETURNS a value for the response header Set-Cookie, e.g.:
  session=732423sdfs73242;
	expires=Fri, 31-Dec-2010 23:59:59 GMT;
	path=/; domain=.example.net
$$;

SELECT type_class_op_method(
	'http_response_refs', 'http_small_text_response_rows',
	'ref_text_op(refs)', 'http_small_response_text(http_response_refs)'
);

SELECT type_class_op_method(
	'http_response_refs', 'http_big_text_response_rows',
	'ref_text_op(refs)', 'http_big_response_text(http_response_refs)'
);

SELECT type_class_op_method(
	'http_response_refs', 'http_binary_response_rows',
	'ref_text_op(refs)', 'http_binary_response_text(http_response_refs)'
);

-- * http_transfer

CREATE OR REPLACE FUNCTION try_new_http_transfer(
	headers http_request_refs[], body bytea,
	OUT http_transfer_refs, OUT uri_refs, OUT uri_query_refs
) AS $$
	SELECT ''
  FROM debug_enter('try_new_http_transfer(http_request_refs[], bytea)', http_requests_text($1));
	INSERT INTO http_transfer_rows(request, request_body)
	VALUES ( $1, get_blob($2) )
	RETURNING	ref, try_get_http_requests_url($1), get_http_requests_cookies($1)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_new_http_transfer(
	headers bytea, body bytea, OUT http_transfer_refs, OUT uri_refs, OUT uri_query_refs
) AS $$
	SELECT try_new_http_transfer(parse_http_requests($1), $2)
	FROM debug_enter('try_new_http_transfer(bytea, bytea)', latin1($1))
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION new_http_transfer(
	headers bytea, body bytea, OUT http_transfer_refs, OUT uri_refs, OUT uri_query_refs
) AS $$
	SELECT _xfer, _url, _cookies	FROM
		try_new_http_transfer($1, $2) foo(_xfer, _url, _cookies),
		debug_enter('new_http_transfer(bytea, bytea)', latin1($1)) _this
	WHERE non_null(_xfer, _this) IS NOT NULL;
$$ LANGUAGE SQL;
COMMENT ON FUNCTION new_http_transfer(bytea, bytea) IS
'return http_transfer associated with header bytea, body bytea arguments';

CREATE OR REPLACE
FUNCTION http_transfer_header_text_(http_request_refs)
RETURNS text AS $$
		SELECT CASE name_
			WHEN http_request_name_type() THEN value_
			WHEN http_request_name_url() THEN ' ' || value_
			WHEN http_request_name_protocol() THEN ' ' || value_
--			WHEN http_request_name_body() THEN E'\n\n' || value_
			WHEN http_request_name_nil() THEN ' ' || value_
			ELSE E'\n' || http_request_text(ref)
		END FROM http_request_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_requests_text_(http_request_refs[])
RETURNS text AS $$
		SELECT array_to_string( ARRAY(
			SELECT http_transfer_header_text_(hdr)
			FROM unnest($1) hdr
		), '' ) || CASE WHEN array_is_empty($1) THEN '' ELSE E'\n' END
$$ LANGUAGE SQL;

COMMENT ON FUNCTION http_requests_text_(http_request_refs[])
IS 'show the request array as a canonical text request';

CREATE OR REPLACE
FUNCTION http_transfer_text(http_transfer_refs)
RETURNS text AS $$
	SELECT
		ref::text || E'\n' ||
		'when: ' || when_::text || E'\n' ||
		E'requests:\n' || http_requests_text_(request) ||
		'requests body length: ' ||
			COALESCE( try_blob_length(request_body)::text || ' bytes', 'NULL!') || E'\n' ||
		COALESCE(
			E'responses:\n'::text || http_responses_text(response), ''
		)
		-- ||
		-- COALESCE(
		-- 	'responses body length: ' || try_blob_length(response_body) || ' bytes', ''
		-- )
	FROM http_transfer_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_requests_text_(http_transfer_refs)
RETURNS text  AS $$
	SELECT http_requests_text_(request)
	FROM http_transfer_rows WHERE ref = $1
$$ LANGUAGE sql;

-- ** http_transfer_classes declarations

-- SELECT type_class_io(
-- 	'http_transfer_refs', 'http_transfer_rows',
-- 	'new_http_transfer(text)', 'http_transfer_text(http_transfer_refs)'
-- );

SELECT type_class_op_method(
	'http_transfer_refs', 'http_transfer_rows',
	'ref_text_op(refs)', 'http_transfer_text(http_transfer_refs)'
);

CREATE OR REPLACE
FUNCTION http_transfer_requests(http_transfer_refs)
RETURNS http_request_refs[] AS $$
	SELECT request FROM http_transfer_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION http_request_headers(
	http_transfer_refs, http_request_name_refs
) RETURNS SETOF http_request_refs AS $$
	SELECT http_requests(http_transfer_requests($1), $2)
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION http_transfer_responses(http_transfer_refs)
RETURNS http_response_refs[] AS $$
	SELECT response FROM http_transfer_rows WHERE ref = $1
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION http_response_headers(
	http_transfer_refs, http_response_name_refs
) RETURNS SETOF http_response_refs AS $$
	SELECT http_responses(http_transfer_responses($1), $2)
$$ LANGUAGE SQL;

/*
CREATE OR REPLACE FUNCTION set_http_transfer_responses(
	 http_transfer_refs, http_response_refs[], bytea
) RETURNS http_transfer_refs AS $$
	UPDATE http_transfer_rows	SET
		 response = array_non_nulls($2),
		 response_body = get_blob($3)
	WHERE ref = $1 AND response IS NULL AND response_body IS NULL
	RETURNING ref
$$ LANGUAGE sql;
*/

CREATE OR REPLACE FUNCTION set_http_transfer_responses(
	 http_transfer_refs, http_response_refs[]
) RETURNS http_transfer_refs AS $$
	UPDATE http_transfer_rows	SET
		 response = array_non_nulls($2)
	WHERE ref = $1 AND response IS NULL
	RETURNING ref
$$ LANGUAGE sql;

-- * A nice way to look at a transaction

CREATE OR REPLACE
FUNCTION show_http_request(http_request_refs[], OUT text, OUT text)
RETURNS SETOF RECORD  AS $$
	SELECT http_request_name_text(name_), value_
	FROM unnest($1), http_request_rows
	WHERE ref = unnest
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION show_http_response(
	http_response_refs[], OUT text, OUT text
) RETURNS SETOF RECORD  AS $$
	SELECT name_value[1], name_value[2] FROM
		unnest($1) response,
		LATERAL http_response_text(response) pair,
		LATERAL try_str_match(pair, '([^:]*): (.*)') name_value
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION show_http_transfer(
	http_transfer_rows,	OUT text, OUT text
) RETURNS SETOF RECORD AS $$
	SELECT 'ref', ($1).ref::refs::text
	UNION SELECT  'when_', ($1).when_::text
	UNION SELECT  'request_', '-->'
	UNION SELECT * FROM show_http_request( ($1).request )
	UNION SELECT  'response_', '-->'
	UNION SELECT * FROM show_http_response( ($1).response )
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION try_show_http_transfer(
	http_transfer_refs, OUT text, OUT text
) RETURNS SETOF RECORD AS $$
	SELECT show_http_transfer(t) FROM http_transfer_rows t
	WHERE ref = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE FUNCTION show_http_transfer(
	http_transfer_refs, OUT text, OUT text
) RETURNS SETOF RECORD AS $$
	SELECT non_null(
		try_show_http_transfer($1), 'show_http_transfer(http_transfer_refs)'
	)
$$ LANGUAGE sql;

-- * Fetching request headers and some syntactic sugar

CREATE OR REPLACE FUNCTION http_transfer_header_values(
	http_transfer_refs, http_request_name_refs
) RETURNS SETOF text AS $$
	SELECT http_request_values(http_transfer_requests($1), $2)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION http_transfer_header_value(
	http_transfer_refs, http_request_name_refs
) RETURNS text AS $$
	SELECT http_transfer_header_values($1, $2) LIMIT 1
$$ LANGUAGE SQL;

DROP OPERATOR IF EXISTS
	^ (http_transfer_refs, http_request_name_refs) CASCADE;

CREATE OPERATOR ^ (
		leftarg = http_transfer_refs,
		rightarg = http_request_name_refs,
		procedure = http_transfer_header_value
);
