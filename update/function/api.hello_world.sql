/* Just for demo */
CREATE OR REPLACE FUNCTION api.hello_world(data text)
RETURNS text AS $$
SELECT 'Hello, world!';
$$ LANGUAGE SQL IMMUTABLE;
