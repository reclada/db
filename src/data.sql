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

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "tag",
        "properties": {
            "name": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "S3Config",
        "properties": {
            "endpointURL": {"type": "string"},
            "regionName": {"type": "string"},
            "accessKeyId": {"type": "string"},
            "secretAccessKey": {"type": "string"},
            "bucketName": {"type": "string"}
            },
        "required": ["accessKeyId", "secretAccessKey", "bucketName"]
    }
}'::jsonb);
