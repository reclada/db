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

    SELECT *
    FROM reclada.v_class
    WHERE for_class = 'tag_2'

select reclada_object.get_schema('tag_2')

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "tag_2",
        "properties": {
            "name_": {"type": "string"}
        },
        "required": ["name_"]
    }
}'::jsonb);
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "DataSource",
        "properties": {
            "name": {"type": "string"},
            "uri": {"type": "string"}
        },
        "required": ["name", "uri"]
    }
}'::jsonb);
SELECT reclada_object.create_subclass('{
    "class": "DataSource",
    "attrs": {
        "newClass": "File",
        "properties": {
            "checksum": {"type": "string"},
            "mimeType": {"type": "string"},
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
    "attributes": {
        "newClass": "DataSet",
        "properties": {
            "name": {"type": "string"},
            "dataSources_": {
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
    "attributes": {
        "name": "defaultDataSet2",
        "dataSources": []
        }
}'::jsonb);

    SELECT *
    FROM reclada.v_class
    WHERE for_class = 'DataSet'
    ORDER BY version DESC