-- version = 2
/*
	you can use "\i 'function/reclada_object.get_schema.sql'"
	to run text script of functions
*/
CREATE EXTENSION IF NOT EXISTS aws_lambda CASCADE;
\i 'function/api.storage_generate_presigned_get.sql'
\i 'function/api.storage_generate_presigned_post.sql'