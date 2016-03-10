-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('http-transfer-code.sql', '$Id');

-- Wicci abstractions for http requests and replies

-- Deprecated Old Text API Functions

-- ** Copyright

-- Copyright (c) 2005-2015, J. Greg Davidson.
-- You may use this file under the terms of the
-- GNU AFFERO GENERAL PUBLIC LICENSE 3.0
-- as specified in the file LICENSE.md included with this distribution.
-- All other use requires my permission in writing.

CREATE OR REPLACE
FUNCTION try_parse_http_head_body_(text, OUT text, OUT text) AS $$
	SELECT head_body[1], head_body[2] FROM try_str_match(
		regexp_replace($1, E'\r', '', 'g'),
		E'^(.*?)(?:\n\n(.*))?$'
	) head_body
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_parse_http_requests(text) 
RETURNS http_request_refs[] AS $$
	SELECT http_headers( _head )	|| CASE
		WHEN _body IS NULL THEN '{}'::http_request_refs[]
		ELSE  ARRAY[try_get_http_request(http_request_name_body(), _body)]
		-- ARRAY[ ... ] non-strict, don't use COALESCE here!
	END FROM
		try_parse_http_head_body_($1) AS foo(_head, _body),
		debug_enter('try_parse_http_requests(text)', $1)
	WHERE _head IS NOT NULL
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION parse_http_requests(text)
RETURNS http_request_refs[] AS $$
	SELECT non_null(
		try_parse_http_requests($1),
		'parse_http_requests(text)'
	)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION try_new_http_transfer(
	http_request_refs[],
	OUT http_transfer_refs, OUT uri_refs, OUT uri_query_refs
) AS $$
	INSERT INTO http_transfer_rows(request)	VALUES ($1)	RETURNING
	ref, try_get_http_requests_url($1), get_http_requests_cookies($1)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION try_new_http_transfer(
	text, OUT http_transfer_refs, OUT uri_refs, OUT uri_query_refs
) AS $$
	SELECT try_new_http_transfer(parse_http_requests($1))
	FROM debug_enter('try_new_http_transfer(text)', $1)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION new_http_transfer(
	text, OUT http_transfer_refs, OUT uri_refs, OUT uri_query_refs
) AS $$
	SELECT _xfer, _url, _cookies
	FROM
		try_new_http_transfer($1) foo(_xfer, _url, _cookies),
		debug_enter('new_http_transfer(text)', $1)
	WHERE non_null(_xfer, 'new_http_transfer(text)') IS NOT NULL;
$$ LANGUAGE SQL;
COMMENT ON FUNCTION new_http_transfer(text) IS
'return http_transfer associated with text argument';

