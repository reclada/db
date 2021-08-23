-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script
DROP EXTENSION IF EXISTS aws_lambda CASCADE;
--{function/api.storage_generate_presigned_get}