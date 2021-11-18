-- version = 42
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

SELECT reclada_object.create_subclass('{
    "class": "DataSource",
    "attributes": {
        "newClass": "Asset",
        "properties": {
            "classGUID": {"type": "string"}
        },
        "required": ["forClass"]
    }
}'::jsonb);

SELECT reclada_object.create_subclass('{
    "class": "Asset",
    "attributes": {
        "newClass": "DBAsset",
        "properties": {
            "connectionString": {"type": "string"}
        },
        "required": ["connectionString"]
    }
}'::jsonb);
