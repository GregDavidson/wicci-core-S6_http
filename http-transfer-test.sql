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

-- I'm now using http_transfer_header_text_(http_request_refs)
-- to test just the header values - I need to test the body values again!!!

-- * Test Functions

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

CREATE OR REPLACE
FUNCTION new_http_xfer(text, bytea = '') RETURNS http_transfer_refs AS $$
	SELECT _xfer
	FROM new_http_transfer( latin1($1), $2 ) foo(_xfer, _url, _cookies)
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION new_http_xfer_(text, text = '') RETURNS http_transfer_refs AS $$
	SELECT new_http_xfer($1, latin1($2))
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE FUNCTION hubba_bytes() RETURNS bytea AS $$
	SELECT latin1(	E'Hubba\r\nHubba\r\n' )
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION hubba_length() RETURNS bigint AS $$
	SELECT octet_length(hubba_bytes())::bigint
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION req_test_get(what TEXT, more TEXT = '')
RETURNS text AS $$
	SELECT 'GET ' || what || E' HTTP/1.1\n'
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION req_test_hdr(hdr TEXT, val TEXT) RETURNS text AS $$
	SELECT hdr || ': ' || val || E'\n'
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION req_test_host(host TEXT) RETURNS text AS $$
	SELECT req_test_hdr('Host', $1)
$$ LANGUAGE SQL IMMUTABLE;

-- replace this with one making sense for the wicci!!!
CREATE OR REPLACE FUNCTION req_test_cookie() RETURNS text AS $$
	SELECT req_test_hdr(	'Cookie',
		 'T3CK=TANT%3D1%7CTANO%3D0; __utma=9273847.914954575.1131235052.1276729496.1276735341.648; user=130136::vFZlZlDruhw229cXcHdgZy; user=130136::vFZlZlDruhw229cXcHdgZy; __utmz=9273847.1276725335.646.2.utmcsr=slashdot.org|utmccn=(referral)|utmcmd=referral|utmcct=/index.pl; CoreID6=22166387201512651447872; __utmc=9273847; __utmb=9273847.1.10.1276735341' )
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION req_test_agent_mozilla() RETURNS text AS $$
	SELECT
--  	text 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.3) Gecko/20100401 SUSE/3.6.3-1.2 Firefox/3.6.3'
 	text 'Mozilla'
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION req_test_agent() RETURNS text AS $$
	SELECT req_test_hdr( 'User-Agent', req_test_agent_mozilla() )
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION req_test_hdrs(host TEXT = NULL)
RETURNS text AS $$
	SELECT CASE WHEN $1 IS NULL THEN '' ELSE req_test_host($1) END
		|| req_test_agent() || req_test_cookie()
$$ LANGUAGE SQL IMMUTABLE;

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

SELECT test_func(
	'first_http_requests(text)',
	http_requests_texts( first_http_requests(_text) ),
	ARRAY[ _text ]
) FROM CAST('User-Agent: Mozilla' AS text) _text;

SELECT test_func(
	'first_http_requests(text)',
	http_requests_texts( first_http_requests('/simple') ),
	ARRAY[ '_type: GET', '_url: /simple' ]
);

SELECT test_func(
	'first_http_requests(text)',
	http_requests_texts( first_http_requests('POST /simple') ),
	ARRAY[ '_type: POST', '_url: /simple' ]
);

SELECT test_func(
	'first_http_requests(text)',
	http_requests_texts( first_http_requests('GET /simple HTTP/1.1') ),
	ARRAY[ '_type: GET', '_url: /simple', '_protocol: HTTP/1.1' ]
);

SELECT test_func(
	'get_http_request(text)',
	http_request_text( get_http_request(_text) ),
	_text
) FROM CAST('foo: bar' AS text) _text;


SELECT test_func(
	'first_http_requests(text)',
	http_requests_texts( first_http_requests(_text) ),
	ARRAY[_text]
) FROM CAST('foo: bar' AS text) _text;


SELECT test_func(
	'http_headers(text)',
 http_requests_texts(
  http_headers(
		req_test_get('/foo')
	) ),
	ARRAY[ '_type: GET','_url: /foo','_protocol: HTTP/1.1' ]
);

SELECT test_func(
	'http_headers(text)',
	http_requests_texts(
  http_headers(
		req_test_get('/foo') || req_test_agent()
	) ),
	ARRAY[ '_type: GET','_url: /foo','_protocol: HTTP/1.1', 'User-Agent: ' || req_test_agent_mozilla() ]
);

-- * http_transfer

SELECT COALESCE(
	http_transfer_rows_ref(x), http_transfer_rows_ref(
		x, new_http_xfer(
			 req_test_get('simple.html') || req_test_host('wicci.org'),
			hubba_bytes()
) ) ) FROM handles('simple') x;

SELECT test_func(
	'http_transfer_header_text_(http_request_refs)',
	http_requests_text_(http_transfer_rows_ref('simple')),
	req_test_get('simple.html') || req_test_host('wicci.org')
);

SELECT test_func(
	'http_transfer_header_values(http_transfer_refs, http_request_name_refs)',
	http_transfer_rows_ref('simple')^'Host',
	'wicci.org'
);

SELECT test_func(
	'http_transfer_header_values(http_transfer_refs, http_request_name_refs)',
	http_transfer_rows_ref('simple')^'_type',
	'GET'
);

SELECT COALESCE(
	http_transfer_rows_ref('simple-greg'),
	http_transfer_rows_ref('simple-greg',
		new_http_xfer(
			req_test_get('simple.html?user=greg@wicci.org')
			|| req_test_host('wicci.org')
			,	hubba_bytes()
) )	) FROM text(E'\r\n') nl;

SELECT COALESCE(
	http_transfer_rows_ref('/.'),
	http_transfer_rows_ref('/.', new_http_xfer_(
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
'Cache-Control: max-age=0' || nl
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
