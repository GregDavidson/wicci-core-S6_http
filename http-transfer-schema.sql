-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('http-transfer-schema.sql', '$Id');

-- Wicci abstractions for http requests and replies

-- ** Copyright

-- Copyright (c) 2005-2015, J. Greg Davidson.
-- You may use this file under the terms of the
-- GNU AFFERO GENERAL PUBLIC LICENSE 3.0
-- as specified in the file LICENSE.md included with this distribution.
-- All other use requires my permission in writing.

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
	 	'http_response_name_refs', '_status', -6
	),
	create_const_ref_func(
	 	'http_response_name_refs', '_doctype', -5
	),
	create_const_ref_func(
		'http_response_name_refs', '_body_lo', -4
	),														-- large object blob
	create_const_ref_func(
		'http_response_name_refs', '_body_hex', -3
	),
	create_const_ref_func(
		'http_response_name_refs', '_body_bin', -2
	),
 create_const_ref_func('http_response_name_refs', '_body', -1);

INSERT INTO http_response_name_rows(ref, name_) VALUES
	(http_response_name_status(), '_status'),
	(http_response_name_doctype(), '_doctype'),
	(http_response_name_body_lo(), '_body_lo'),
	(http_response_name_body_hex(), '_body_hex'),
	(http_response_name_body_bin(), '_body_bin'),
	(http_response_name_body(), '_body');

-- * http_request

SELECT create_ref_type('http_request_refs');

CREATE TABLE IF NOT EXISTS http_request_keys (
	key http_request_refs PRIMARY KEY
);

SELECT create_key_trigger_functions_for('http_request_keys');

CREATE TABLE IF NOT EXISTS http_request_rows (
	ref http_request_refs NOT NULL,
  name_ http_request_name_refs NOT NULL,
	value_ text NOT NULL
);

COMMENT ON TABLE http_request_rows IS
'PostgreSQL doesn''t allow us to have indices like unique
constraints on fields of size above 1/3 of a buffer page,
i.e. 2712 bytes which is a problem for text!';

SELECT declare_abstract('http_request_rows');

CREATE TABLE IF NOT EXISTS http_small_request_rows (
	PRIMARY KEY(ref),
  CONSTRAINT http_small_request_rows__small
		CHECK (octet_length(value_) < max_indexable_field_size()),
	UNIQUE(name_, value_)
) INHERITS (http_request_rows);

SELECT declare_ref_class_with_funcs('http_small_request_rows');
SELECT create_simple_serial('http_small_request_rows');
SELECT create_key_triggers_for('http_small_request_rows', 'http_request_keys');

CREATE TABLE IF NOT EXISTS http_big_request_rows (
	PRIMARY KEY(ref),
  CONSTRAINT http_big_request_rows__big
		CHECK (octet_length(value_) >= max_indexable_field_size()),
	hash_ hashes,
	UNIQUE(name_, hash_)
) INHERITS (http_request_rows);

SELECT declare_ref_class_with_funcs('http_big_request_rows');
SELECT create_simple_serial('http_big_request_rows');
SELECT create_key_triggers_for('http_big_request_rows', 'http_request_keys');

-- * http_response

SELECT create_ref_type('http_response_refs');

CREATE TABLE IF NOT EXISTS http_response_keys (
	key http_response_refs PRIMARY KEY
);

SELECT create_key_trigger_functions_for('http_response_keys');

CREATE TABLE IF NOT EXISTS http_response_rows (
	ref http_response_refs PRIMARY KEY,
  name_ http_response_name_refs NOT NULL
		REFERENCES http_response_name_rows,
	text_value text,
	binary_value bytea,
	CHECk( (text_value IS NULL) != (binary_value IS NULL) )
);

COMMENT ON TABLE http_response_rows IS
'What if we push the *_value fields into the appropriate child tables???
Logically we should have four child tables for
text/binary X big/small.  Pragmatically we may have very few
small binary files, so the current system might want to stand.';

SELECT declare_abstract('http_response_rows');

CREATE TABLE IF NOT EXISTS http_big_response_rows (
	hash_ hashes NOT NULL
) INHERITS (http_response_rows);

SELECT declare_abstract('http_big_request_rows');

CREATE TABLE IF NOT EXISTS http_small_text_response_rows (
	PRIMARY KEY(ref),
  CONSTRAINT http_small_text_response_rows__small CHECK (
		text_value IS NOT NULL AND octet_length(text_value) < max_indexable_field_size()
	),
	UNIQUE(name_, text_value)
) INHERITS (http_response_rows);

SELECT declare_ref_class_with_funcs('http_small_text_response_rows');
SELECT create_simple_serial('http_small_text_response_rows');
SELECT create_key_triggers_for('http_small_text_response_rows', 'http_response_keys');
SELECT create_handles_for('http_small_text_response_rows');

CREATE TABLE IF NOT EXISTS http_big_text_response_rows (
	PRIMARY KEY(ref),
  CONSTRAINT http_big_text_response_rows__big CHECK (
		text_value IS NOT NULL AND octet_length(text_value) >= max_indexable_field_size()
	),
	UNIQUE(name_, hash_)
) INHERITS (http_big_response_rows);

SELECT declare_ref_class_with_funcs('http_big_text_response_rows');
SELECT create_simple_serial('http_big_text_response_rows');
SELECT create_key_triggers_for('http_big_text_response_rows', 'http_response_keys');

CREATE TABLE IF NOT EXISTS http_binary_response_rows (
	PRIMARY KEY(ref),
  constraint http_binary_response_rows__binary_value
	CHECK (binary_value IS NOT NULL),
	UNIQUE(name_, hash_)
) INHERITS (http_big_response_rows);

SELECT declare_ref_class_with_funcs('http_binary_response_rows');
SELECT create_simple_serial('http_binary_response_rows');
SELECT create_key_triggers_for('http_binary_response_rows', 'http_response_keys');

DELETE FROM http_response_rows*;	-- including rows of child tables

CREATE OR REPLACE
FUNCTION try_http_response_name(http_response_refs) 
RETURNS http_response_name_refs AS $$
	SELECT name_ FROM http_response_rows* WHERE ref = $1
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

INSERT INTO http_small_text_response_rows(ref, name_, text_value)
VALUES (http_response_nil(), http_response_name_nil(), '');

-- * http_transfer

-- * type http_transfer_refs, class http_transfer_rows

SELECT create_ref_type('http_transfer_refs');

CREATE TABLE IF NOT EXISTS http_transfer_rows (
	ref http_transfer_refs PRIMARY KEY,
	when_ timestamp NOT NULL DEFAULT('now'),
	request http_request_refs[],
	request_body blob_refs NOT NULL REFERENCES blob_rows,
	response http_response_refs[] DEFAULT NULL,
	response_body blob_refs REFERENCES blob_rows DEFAULT NULL
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
	lang doc_lang_name_refs PRIMARY KEY,
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
