-- version = 24
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/dev.reg_notice.sql'

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "Context",
        "properties": {
            "Lambda": {"type": "string"}
			,"Environment": {"type": "string"}
        },
        "required": ["Environment"]
    }
}'::jsonb);


DELETE
FROM reclada.object
WHERE class = reclada_object.get_jsonschema_GUID() and attributes->>'forClass'='Lambda';

\i 'function/api.storage_generate_presigned_get.sql'
\i 'function/api.storage_generate_presigned_post.sql'
\i 'function/reclada.datasource_insert_trigger_fnc.sql'