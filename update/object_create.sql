------------- jsonschema
-- 1
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "tag",
        "properties": {
            "name": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);
-- 2
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "DataSource",
        "properties": {
            "name": {"type": "string"},
            "uri": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);
-- 3
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
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
-- 4
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
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
-- 5
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
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
            "attributes": {
                "type": "array", 
                "items": {"type": "string"}
            }
        },
        "required": ["class", "channelName", "event"]
    }
}'::jsonb);
-- 6
SELECT reclada_object.create_subclass('{
            "class": "RecladaObject",
            "attributes": {
                "newClass": "Index",
                "properties": {
                    "name": {"type": "string"},
                    "method": {
                        "type": "string",
                        "enum ": [
                            "btree", 
                            "hash" , 
                            "gist" , 
                            "gin"
                        ]
                    },
                    "wherePredicate": {
                        "type": "string"
                    },
                    "fields": {
                        "items": {
                            "type": "string"
                        },
                        "type": "array",
                        "minContains": 1
                    }
                },
                "required": ["name","fields"]
            }
        }'::jsonb);
-- 7
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "Component",
        "properties": {
            "name": {"type": "string"},
            "commitHash": {"type": "string"},
            "repository": {"type": "string"}
        },
        "required": ["name","commitHash","repository"]
    }
}'::jsonb);
-- 8
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "Context",
        "properties": {
            "Lambda": {"type": "string"},
            "Region": {"type": "string"},
            "Environment": {"type": "string"}
        },
        "required": ["Lambda","Region","Environment"]
    }
}'::jsonb);
-- 9
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "DTOJsonSchema",
        "properties": {
            "schema": {"type": "object"},
            "function": {"type": "string"}
        },
        "required": ["schema","function"]
    }
}'::jsonb);
-- 10
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {

        "dupBehavior": "Replace",
        "dupChecking": [
            {
                "isMandatory": true,
                "uniFields": [
                    "uri"
                ]
            },
            {
                "isMandatory": true,
                "uniFields": [
                    "checksum"
                ]
            }
        ],
        "isCascade": true,

        "newClass": "File",
        "properties": {
            "uri": {"type": "string"},
            "name": {"type": "string"},
            "mimeType": {"type": "string"},
            "checksum": {"type": "string"}
        },
        "required": ["uri","mimeType","name"]
    }
}'::jsonb);
-- 11
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "User",
        "properties": {
            "login": {"type": "string"}
        },
        "required": ["login"]
    }
}'::jsonb);
-- 12
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "ImportInfo",
        "properties": {
            "tranID": {"type": "number"},
            "name": {"type": "string"}
        },
        "required": ["tranID","name"]
    }
}'::jsonb);
-- 13
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "Asset",
        "properties": {
            "name": {"type": "string"},
            "uri": {"type": "string"}
        },
        "required": ["name"]
    }
}'::jsonb);
-- 14
SELECT reclada_object.create_subclass('{
    "class": "Asset",
    "attributes": {
        "newClass": "DBAsset"
    }
}'::jsonb);
-- 15
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "revision",
        "properties": {
            "branch": {"type": "string"},
            "user": {"type": "string"},
            "num": {"type": "number"},
            "dateTime": {"type": "string"}
        },
        "required": ["dateTime"]
    }
}'::jsonb);

------------- defaultDataSet
SELECT reclada_object.create('{
    "class": "DataSet",
    "attributes": {
        "name": "defaultDataSet",
        "dataSources": []
    }
}'::jsonb);


------------- Context
SELECT reclada_object.create('{
        "GUID": "db0bb665-6aa4-45d5-876c-173a7e921f94",
        "class": "Context",
        "attributes": {
            "Lambda": "#@#lname#@#",
            "Region": "#@#lregion#@#",
            "Environment": "#@#ename#@#"
        }    
    }'::jsonb);

------------- Index
select reclada_object.create('{
        "GUID": "db0873d1-786f-4d5d-b790-5c3b3cd29baf",
        "class": "Index",
        "attributes": {
            "name": "checksum_index_",
            "fields": ["(attributes ->> ''checksum''::text)"],
            "method": "hash",
            "wherePredicate": "((attributes ->> ''checksum''::text) IS NOT NULL)"
        }
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db08d53b-c423-4e94-8b14-e73ebe98e991",
        "class": "Index",
        "attributes": {
            "name": "repository_index_",
            "fields": ["(attributes ->> ''repository''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''repository''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
    "GUID": "db05e253-7954-4610-b094-8f9925ea77b4",
    "class": "Index",
    "attributes": {
            "name": "commithash_index_",
            "fields": ["(attributes ->> ''commitHash''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''commitHash''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
    "GUID": "db02f980-cd5a-4c1a-9341-7a81713cd9d0",
    "class": "Index",
    "attributes": {
            "name": "fields_index_",
            "fields": ["(attributes ->> ''fields''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''fields''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0e400b-1da4-4823-bb80-15eb144a1639",
        "class": "Index",
        "attributes": {
                "name": "caption_index_",
                "fields": ["(attributes ->> ''caption''::text)"],
                "method": "btree",
                "wherePredicate": "((attributes ->> ''caption''::text) IS NOT NULL)"
            }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db09fafb-91b1-4fe6-8e5c-1cd2d7d9225a",
        "class": "Index",
        "attributes": {
            "name": "type_index",
            "fields": ["(attributes ->> ''type''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''type''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0118e5-ea34-45dc-b72c-f16f6a628ddb",
        "class": "Index",
        "attributes": {
            "name": "schema_index_",
            "fields": ["(attributes ->> ''schema''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''schema''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db07c919-5bc0-4fec-961c-f558401d3e71",
        "class": "Index",
        "attributes": {
            "name": "forclass_index_",
            "fields": ["(attributes ->> ''forclass''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''forclass''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0184b8-556e-4f57-af12-d84066adbe31",
        "class": "Index",
        "attributes": {
            "name": "revision_index",
            "fields": ["(attributes ->> ''revision''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''revision''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0e22c0-e0d7-4b11-bf25-367a8fbdef83",
        "class": "Index",
        "attributes": {
            "name": "subject_index_",
            "fields": ["(attributes ->> ''subject''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''subject''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db05c9c7-17ce-4b36-89d7-81b0ddd26a6a",
        "class": "Index",
        "attributes": {
            "name": "class_index_",
            "fields": ["(attributes ->> ''class''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''class''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0a88c1-ac00-42e5-9caa-6007a1c948c6",
        "class": "Index",
            "attributes": {
            "name": "name_index_",
            "fields": ["(attributes ->> ''name''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''name''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0fdc46-6479-4d20-bd21-a6330905e45b",
        "class": "Index",
        "attributes": {
            "name": "event_index_",
            "fields": ["(attributes ->> ''event''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''event''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db02b45a-acfd-4448-a51a-8e7dc35bf3af",
        "class": "Index",
        "attributes": {
            "name": "function_index_",
            "fields": ["(attributes ->> ''function''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''function''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0b797a-b287-4282-b0f8-d985c7a439f4",
        "class": "Index",
        "attributes": {
            "name": "login_index_",
            "fields": ["(attributes ->> ''login''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''login''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db03c715-c0f9-43c3-940a-803aafa513e0",
        "class": "Index",
        "attributes": {
            "name": "object_index_",
            "fields": ["(attributes ->> ''object''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''object''::text) IS NOT NULL)"
        }    
    }'::jsonb);
