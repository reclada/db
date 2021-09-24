-- version = 31
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "ImportInfo",
        "properties": {
            "name": {
                "type": "string"
            },
            "tranID": {
                "type": "number"
            }
        },
        "required": ["name","tranID"]
    }
}'::jsonb);


\i 'function/reclada.raise_exception.sql'
\i 'function/reclada_object.create.sql' 
\i 'view/reclada.v_import_info.sql'
\i 'view/reclada.v_object.sql'
\i 'function/reclada.get_transaction_id_for_import.sql'
\i 'function/reclada_object.delete.sql'
\i 'function/reclada_object.is_equal.sql'
\i 'function/reclada.rollback_import.sql'


CREATE INDEX IF NOT EXISTS revision_index ON reclada.object ((attributes->>'revision'));
CREATE INDEX IF NOT EXISTS job_status_index ON reclada.object ((attributes->>'status'));
CREATE INDEX IF NOT EXISTS runner_type_index  ON reclada.object ((attributes->>'type'));