-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('wicci-http.sql', '$Id');

-- Wicci abstractions for http requests and replies

-- ** Copyright

-- Copyright (c) 2005-2012, J. Greg Davidson.
-- You may use this file under the terms of the
-- GNU AFFERO GENERAL PUBLIC LICENSE 3.0
-- as specified in the file LICENSE.md included with this distribution.
-- All other use requires my permission in writing.

-- SET ROLE TO WICCI1;

-- * the header-name classes

-- SELECT create_name_ref_schema(
-- 	'http_request_name', _norm := 'str_trim_lower(text)'
-- );
DROP table if exists http_request_name_rows CASCADE;
SELECT create_name_ref_schema(
	'http_request_name', name_type := 'citext'
);

COMMENT ON COLUMN http_request_name_rows.name_ IS
'when the first character is underscore the ref_id is negative;
this is not a header value which came from the browser.';

SELECT
	create_const_ref_func('http_request_name_refs', '_type', -4),
	create_const_ref_func('http_request_name_refs', '_url', -3),
	create_const_ref_func('http_request_name_refs','_protocol',-2),
	create_const_ref_func('http_request_name_refs', '_body', -1);

INSERT INTO http_request_name_rows(ref, name_) VALUES
	(http_request_name_type(), '_type'),
	(http_request_name_url(), '_url'),
	(http_request_name_protocol(), '_protocol'),
	(http_request_name_body(), '_body');

-- SELECT create_name_ref_schema(
-- 	'http_response_name', _norm := 'str_trim_lower(text)'
-- );
SELECT create_name_ref_schema(
	'http_response_name', name_type := 'text'
);

COMMENT ON COLUMN http_response_name_rows.name_ IS
'when the first character is underscore the ref_id is negative;
this header name will not be sent to the browser.';

SELECT
	create_const_ref_func(
	 	'http_response_name_refs', '_status', -5
	),
	create_const_ref_func(
	 	'http_response_name_refs', '_doctype', -4
	),
	create_const_ref_func(
		'http_response_name_refs', '_body_lo', -3
	),														-- large object blob
	create_const_ref_func(
		'http_response_name_refs', '_body_hex', -2
	),														-- not yet used!!
 create_const_ref_func('http_response_name_refs', '_body', -1);

INSERT INTO http_response_name_rows(ref, name_) VALUES
	(http_response_name_status(), '_status'),
	(http_response_name_doctype(), '_doctype'),
	(http_response_name_body_lo(), '_body_lo'),
	(http_response_name_body_hex(), '_body_hex'), -- unused!!
	(http_response_name_body(), '_body');

-- * http_request

SELECT create_ref_type('http_request_refs');

CREATE OR REPLACE
FUNCTION ref_ugly_text(refs, text = NULL) RETURNS text AS $$
	SELECT '{' || s1_refs.ref_tag($1) || ',' || s1_refs.ref_id($1) || (COALESCE( ',' || md5($2), '')) || '}'
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION 
ref_ugly_text(refs, text) IS
'Converts a reference plus an optional, possibly large
string into a single modestly-sized string by converting the
possibly-large string to an md5 hash.';

CREATE TABLE IF NOT EXISTS http_request_rows (
	ref http_request_refs PRIMARY KEY,
  name_ http_request_name_refs NOT NULL
		REFERENCES http_request_name_rows,
	-- value_ text -- old
	value_ text NOT NULL	-- newdiff 2012-7-9 !!
	--, UNIQUE (name_, value_) -- newdiff 2012-7-9!!
);
CREATE UNIQUE INDEX http_request_rows_ugly
ON http_request_rows ((ref_ugly_text(name_, value_))) ;
COMMENT ON INDEX http_request_rows_ugly IS
'PostgreSQL does not like btree indices on text above 1/3 of
a buffer page, i.e. 2712 bytes.  I might want to consider
creating a hashed-text type to deal with such situations
more generally.';

SELECT declare_ref_class_with_funcs('http_request_rows');
SELECT create_simple_serial('http_request_rows');

-- * http_response

SELECT create_ref_type('http_response_refs');

CREATE TABLE IF NOT EXISTS http_response_rows (
	ref http_response_refs PRIMARY KEY,
  name_ http_response_name_refs NOT NULL
		REFERENCES http_response_name_rows,
	value_ text NOT NULL
	-- ,	UNIQUE (name_, value_) -- newdiff 2012-7-9!!
);
CREATE UNIQUE INDEX http_response_rows_ugly
ON http_response_rows ((ref_ugly_text(name_, value_)));
COMMENT ON INDEX http_response_rows_ugly IS
'PostgreSQL does not like btree indices on text above 1/3 of
a buffer page, i.e. 2712 bytes.  I might want to consider
creating a hashed-text type to deal with such situations
more generally.';

DELETE FROM http_response_rows;

SELECT create_handles_for('http_response_rows');

CREATE OR REPLACE
FUNCTION try_http_response_name(http_response_refs) 
RETURNS http_response_name_refs AS $$
	SELECT name_ FROM http_response_rows WHERE ref = $1
$$ LANGUAGE sql STRICT;

CREATE OR REPLACE
FUNCTION http_response_name(http_response_refs)
RETURNS http_response_name_refs  AS $$
	SELECT non_null(
		try_http_response_name($1),
		'http_response_name(http_response_refs)'
	)
$$ LANGUAGE sql;

SELECT declare_ref_class_with_funcs('http_response_rows');
SELECT create_simple_serial('http_response_rows');

INSERT INTO http_response_rows(ref, name_, value_)
VALUES (http_response_nil(), http_response_name_nil(), '');

-- * http_transfer

-- * type http_transfer_refs, class http_transfer_rows

SELECT create_ref_type('http_transfer_refs');

CREATE TABLE IF NOT EXISTS http_transfer_rows (
	ref http_transfer_refs PRIMARY KEY,
	when_ timestamp NOT NULL DEFAULT('now'),
	request http_request_refs[],
--	url uri_refs DEFAULT NULL,		-- constructed from the request
--	cookies uri_query_refs DEFAULT NULL,		-- ditto
	response http_response_refs[] DEFAULT NULL
--	req text											-- for debugging, will go away!
);
COMMENT ON TABLE http_transfer_rows IS
'represents a wicci transfer; i.e. an http request or reply;
The uri & cookies columns should go away in favor of passing
those values as parameters of the page-serve functions.
';

COMMENT ON COLUMN http_transfer_rows.response IS
'set via a single update after request processing complete';

-- COMMENT ON COLUMN http_transfer_rows.url IS
-- 'Deprecated, now a parameter of page-serve functions!!';

-- COMMENT ON COLUMN http_transfer_rows.cookies IS
-- 'Deprecated, now a parameter of page-serve functions!!';

-- COMMENT ON COLUMN http_transfer_rows.req IS
-- 'Deprecated, for debugging only!!';

SELECT create_handles_for('http_transfer_rows');

SELECT declare_ref_class_with_funcs(
	'http_transfer_rows', _updateable_ := true
);

SELECT create_simple_serial('http_transfer_rows');

-- * doc_langs_content_type

CREATE TABLE IF NOT EXISTS doc_langs_content_type (
	lang_ doc_lang_name_refs PRIMARY KEY,
	content_type text NOT NULL	
);


-- * the header-name classes

-- ** http_request

SELECT declare_http_request_name(
	'Accept',
	'Accept-Charset',
	'Accept-Encoding',
	'Accept-Language',
	'Connection',
	'Cookie',
	'Get-Argument',
	'Header',
	'Host',												-- target domain of request
	'Keep-Alive',
	'PostData',
	'Response-Header',
	'User-Agent'
);

-- ** http_response

-- This is a subset of the standard response headers yet
-- it is much more than we need right now.
-- It may be that we will need to iterate through
SELECT declare_http_response_name(
	'Content-Language',
	'Content-Length',				-- in bytes.
	'Content-Type',					-- Content type of the resource'
	'Date',					 -- Date and time at which the message was originated.
	'Expect',	-- should client application expect 100 series responses.?
	'Expires', -- Date and time past which resource would be outdated.
	'Retry-After',						 -- time service expected to be unavailable.
	'Server',	--  software used by origin server to handle the request.
	'Set-Cookie',									 -- Value of cookie set for the request.
	'Status-Code', -- Status code returned by the server
	'Status-Text', -- additional text returned on the response line.
	'Version',		 -- Last response code returned by the server.
	'Warning' -- Additional info on response status beyond status code.
);
