INSERT INTO reclada.object VALUES(format(
    '{
        "class": "jsonschema",
        "attrs": {
            "forClass": "jsonschema",
            "schema": {
                "type": "object",
                "properties": {
                    "forClass": {"type": "string"},
                    "schema": {"type": "object"}
                },
                "required": ["forClass", "schema"]
            }
        },
        "id": "%s",
        "revision": %s
    }', uuid_generate_v4(), reclada_revision.create('', NULL)
    )::jsonb
);
SELECT reclada_object.create('{
    "class": "jsonschema",
    "attrs": {
        "forClass": "RecladaObject",
        "schema": {
            "type": "object",
            "properties": {
                "tags": {
                    "type": "array",
                    "items": {
                        "type": "string"
                    }
                }
            },
            "required": []
        }
    }
}'::jsonb);

SELECT api.reclada_object_create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "tag",
        "properties": {
            "name": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);
SELECT api.reclada_object_create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "DataSource",
        "properties": {
            "name": {"type": "string"},
            "uri": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);
SELECT api.reclada_object_create_subclass('{
    "class": "DataSource",
    "attrs": {
        "newClass": "File",
        "properties": {
            "checksum": {"type": "string"},
            "mimeType": {"type": "string"}
        },
        "required": ["checksum", "mimeType"]
    }
}'::jsonb);
SELECT api.reclada_object_create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "DataSet",
        "properties": {
            "name": {"type": "string"},
            "dataSources": {
                "type": "array",
                "items": {"type": "string"}
            }
        },
        "required": ["name"]
    }
}'::jsonb);
