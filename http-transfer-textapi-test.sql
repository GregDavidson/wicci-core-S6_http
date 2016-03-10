-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('http-transfer-textapi-test.sql', '$Id');

-- Wicci abstractions for http requests and replies

-- ** Copyright

-- Copyright (c) 2005-2015, J. Greg Davidson.
-- You may use this file under the terms of the
-- GNU AFFERO GENERAL PUBLIC LICENSE 3.0
-- as specified in the file LICENSE.md included with this distribution.
-- All other use requires my permission in writing.

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
