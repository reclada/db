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
            "transactionID": {
                "type": "number"
            }
        },
        "required": ["name","transactionID"]
    }
}'::jsonb);

-- TODO: create object

\i 'function/reclada_object.create.sql' 
\i 'view/reclada.v_import_info.sql'
\i 'function/reclada.get_transaction_id_for_import.sql'
\i 'function/reclada_object.delete.sql'







