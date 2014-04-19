-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('http-transfer-test.sql', '$Id');

-- ** Copyright

-- Copyright (c) 2005-2012, J. Greg Davidson.
-- You may use this file under the terms of the
-- GNU AFFERO GENERAL PUBLIC LICENSE 3.0
-- as specified in the file LICENSE.md included with this distribution.
-- All other use requires my permission in writing.

-- * handy test functions

CREATE OR REPLACE
FUNCTION drop_http_response(http_transfer_refs)
RETURNS http_transfer_refs  AS $$
	UPDATE http_transfer_rows
		SET response=NULL
	WHERE ref = $1 RETURNING ref
$$ LANGUAGE sql;

COMMENT ON
FUNCTION drop_http_response(http_transfer_refs)
IS 'Reset results, for testing framework only!!!';

CREATE OR REPLACE
FUNCTION fresh_http_transfer(handles)
RETURNS http_transfer_refs  AS $$
	SELECT drop_http_response( non_null(
		http_transfer_rows_ref($1),
		'fresh_http_transfer(handles)'
	) )
$$ LANGUAGE sql;

COMMENT ON FUNCTION fresh_http_transfer(handles)
IS 'Reset results, for testing framework only!!!';

-- * http_request_name

SELECT test_func(
	'find_http_request_name(citext)',
	find_http_request_name('User-Agent')::text,
	'User-Agent'
);

SELECT test_func(
	'http_request_name_length(http_request_name_refs)',
	http_request_name_length('User-Agent'),
	10
);

SELECT test_func(
	'http_request_name_length(http_request_name_refs)',
	ref_length_op(find_http_request_name('User-Agent'))::integer,
	10
);

-- * http_request

CREATE OR REPLACE
FUNCTION http_requests_texts(http_request_refs[])
RETURNS text[] AS $$
	SELECT ARRAY(
		SELECT http_request_text(x)
		FROM unnest( $1 ) x
	)
$$ LANGUAGE SQL;

SELECT http_requests_texts(
	first_http_requests('User-Agent: Mozilla')
);

-- BUG!!! - returns NULL value!
-- {"_nil: foo: bar"}
SELECT http_request_text(
  get_http_request('foo: bar')
);

-- BUG!!!
-- {"_nil: foo: bar"}
SELECT http_requests_texts(
  first_http_requests('foo: bar')
);

SELECT http_requests_texts(
  first_http_requests('/foo')
);

SELECT http_requests_texts(
  first_http_requests('GET /foo')
);

SELECT http_requests_texts(
  first_http_requests('GET /foo HTTP/1.1')
);

SELECT http_requests_texts(
  http_head(
		'GET /foo HTTP/1.1' || E'\n'
		|| 'User-Agent: Mozilla'
	)
);

SELECT
  try_parse_http_head_body_(
		'GET /foo HTTP/1.1' || E'\n\r'
		|| 'User-Agent: Mozilla'
);

SELECT
  try_parse_http_head_body_(
		'GET /foo HTTP/1.1' || E'\n\r'
		|| 'User-Agent: Mozilla' || E'\n\r'
);

SELECT
  try_parse_http_head_body_(
		'GET /foo HTTP/1.1' || E'\n\r'
		|| 'User-Agent: Mozilla' || E'\n\r' || E'\n\r'
		|| 'This is my body!' || E'\n\r'
);

SELECT
  parse_http_requests(
		'GET /foo HTTP/1.1' || E'\r\n'
		|| 'User-Agent: Mozilla'
);

SELECT http_requests_texts(
  parse_http_requests(
		'GET /foo HTTP/1.1' || E'\r\n'
		|| 'User-Agent: Mozilla' || E'\r\n'
		|| E'\r\n' || E'\r\n'
	)
);

SELECT http_requests_texts(
  parse_http_requests(
		'GET /foo HTTP/1.1' || E'\r\n'
		|| 'User-Agent: Mozilla' || E'\r\n'
		|| E'\r\n'
		|| 'Hubba' || E'\r\n'
		|| 'Hubba' || E'\r\n'
	)
);

-- * http_transfer

CREATE OR REPLACE
FUNCTION new_http_xfer(text) RETURNS http_transfer_refs AS $$
	SELECT _xfer
	FROM new_http_transfer($1) foo(_xfer, _url, _cookies)
$$ LANGUAGE SQL STRICT;

SELECT COALESCE(
	http_transfer_rows_ref(x), http_transfer_rows_ref(
		x, new_http_xfer(
			'GET simple.html HTTP/1.1' || nl
			|| 'User-Agent: Mozilla' || nl
			|| nl
			|| 'Hubba' || nl
			|| 'Hubba' || nl
) )	) FROM handles('simple') x, text(E'\r\n') nl;

SELECT test_func(
	'http_transfer_header_text_(http_request_refs)',
	http_requests_text(http_transfer_rows_ref('simple')),
			'GET simple.html HTTP/1.1' || nl
			|| 'User-Agent: Mozilla' || nl
			|| nl
			|| 'Hubba' || nl
			|| 'Hubba' || nl
) FROM text(E'\n') nl;

SELECT test_func(
	'http_transfer_header_values(http_transfer_refs, http_request_name_refs)',
	http_transfer_rows_ref('simple')^'User-Agent',
	'Mozilla'
);

SELECT test_func(
	'http_transfer_header_values(http_transfer_refs, http_request_name_refs)',
	http_transfer_rows_ref('simple')^'_type',
	'GET'
);

SELECT COALESCE(
	http_transfer_rows_ref('host-simple'),
	http_transfer_rows_ref('host-simple',
		new_http_xfer(
			'GET /simple HTTP/1.1' || nl
			|| 'Host: wicci.org' || nl
			|| 'User-Agent: Mozilla' || nl
			|| nl
			|| 'Hubba' || nl
			|| 'Hubba' || nl
) )	) FROM text(E'\r\n') nl;

SELECT COALESCE(
	http_transfer_rows_ref('host-simple-greg'),
	http_transfer_rows_ref('host-simple-greg',
		new_http_xfer(
			'GET /simple?user=greg@wicci.org HTTP/1.1' || nl
			|| 'Host: wicci.org' || nl
			|| 'User-Agent: Mozilla' || nl
			|| nl
			|| 'Hubba' || nl
			|| 'Hubba' || nl
) )	) FROM text(E'\r\n') nl;

SELECT COALESCE(
	http_transfer_rows_ref('/.'),
	http_transfer_rows_ref('/.', new_http_xfer(
'GET / HTTP/1.1' || nl ||
'Host: slashdot.org' || nl ||
'User-Agent: Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.3) Gecko/20100401 SUSE/3.6.3-1.2 Firefox/3.6.3' || nl ||
'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' || nl ||
'Accept-Language: en-us,en;q=0.5' || nl ||
'Accept-Encoding: gzip,deflate' || nl ||
'Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7' || nl ||
'Keep-Alive: 115' || nl ||
'Connection: keep-alive' || nl ||
'Cookie: T3CK=TANT%3D1%7CTANO%3D0; __utma=9273847.914954575.1131235052.1276729496.1276735341.648; user=130136::vFZlZlDruhw229cXcHdgZy; user=130136::vFZlZlDruhw229cXcHdgZy; __utmz=9273847.1276725335.646.2.utmcsr=slashdot.org|utmccn=(referral)|utmcmd=referral|utmcct=/index.pl; CoreID6=22166387201512651447872; __utmc=9273847; __utmb=9273847.1.10.1276735341' || nl ||
'Cache-Control: max-age=0' || nl || nl
) )	) FROM text(E'\r\n') nl;;


SELECT test_func(
	'http_transfer_header_values(http_transfer_refs, http_request_name_refs)',
	http_transfer_rows_ref('/.')^'User-Agent',
	'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.3) Gecko/20100401 SUSE/3.6.3-1.2 Firefox/3.6.3'
);

SELECT test_func(
	'http_transfer_header_values(http_transfer_refs, http_request_name_refs)',
	http_transfer_rows_ref('/.')^'_type',
	'GET'
);
