-- version = 22
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "Lambda",
        "properties": {
            "name": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);

\i 'function/api.storage_generate_presigned_post.sql'
\i 'function/reclada.datasource_insert_trigger_fnc.sql'



