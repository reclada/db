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
        "revision": %s,
        "isDeleted": false
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
        "newClass": "DataSource",
        "properties": {
            "name": {"type": "string"},
            "uri": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);
SELECT reclada_object.create_subclass('{
    "class": "DataSource",
    "attrs": {
        "newClass": "File",
        "properties": {
            "checksum": {"type": "string"},
            "mimeType": {"type": "string"},
            "name": {"type": "string"},
            "uri": {"type": "string"}
        },
        "required": ["checksum", "mimeType"]
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
SELECT reclada_object.create_subclass('{
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

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attrs": {
        "newClass": "Message",
        "properties": {
            "channelName": {"type": "string"},
            "class": {"type": "string"},
            "event": {
                "type": "string",
                "enum": [
                    "create",
                    "update",
                    "list",
                    "delete"
                ]
            },
            "attrs": {"type": "array", "items": {"type": "string"}}
        },
        "required": ["class", "channelName", "event"]
    }
}'::jsonb);

/* Just for demo */
SELECT reclada_object.create('{
    "class": "DataSet",
    "attrs": {
        "name": "defaultDataSet",
        "dataSources": []
        }
}'::jsonb);