
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
--{ 4 DataSet
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

        SELECT reclada_object.create('{
            "GUID":"10c400ff-a328-450d-ae07-ce7d427d961c",
            "class": "DataSet",
            "attributes": {
                "name": "defaultDataSet",
                "dataSources": []
            }
        }'::jsonb);
--} 4 DataSet

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

--{ 6 Index
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

--} 6 Index

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

--{ 9 DTOJsonSchema
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

    SELECT reclada_object.create('{
            "GUID":"db0bf6f5-7eea-4dbd-9f46-e0535f7fb299",
            "class": "DTOJsonSchema",
            "attributes": {
                "function": "reclada_object.get_query_condition_filter",
                "schema": {
                    "id": "expr",
                    "type": "object",
                    "required": [
                        "value",
                        "operator"
                    ],
                    "properties": {
                        "value": {
                            "type": "array",
                            "items": {
                                "anyOf": [
                                    {
                                        "type": "string"
                                    },
                                    {
                                        "type": "null"
                                    },
                                    {
                                        "type": "number"
                                    },
                                    {
                                        "$ref": "expr"
                                    },
                                    {
                                        "type": "boolean"
                                    },
                                    {
                                        "type": "array",
                                        "items": {
                                            "anyOf": [
                                                {
                                                    "type": "string"
                                                },
                                                {
                                                    "type": "number"
                                                }
                                            ]
                                        }
                                    }
                                ]
                            },
                            "minItems": 1
                        },
                        "operator": {
                            "type": "string"
                        }
                    }
                }
            }
        }'::jsonb);

     SELECT reclada_object.create('{
            "GUID":"db0ad26e-a522-4907-a41a-a82a916fdcf9",
            "class": "DTOJsonSchema",
            "attributes": {
                "function": "reclada_object.list",
                "schema": {
                    "type": "object",
                    "anyOf": [
                        {
                            "required": [
                                "transactionID"
                            ]
                        },
                        {
                            "required": [
                                "class"
                            ]
                        },
                        {
                            "required": [
                                "filter"
                            ]
                        }
                    ],
                    "properties": {
                        "class": {
                            "type": "string"
                        },
                        "limit": {
                            "anyOf": [
                                {
                                    "enum": [
                                        "ALL"
                                    ],
                                    "type": "string"
                                },
                                {
                                    "type": "integer"
                                }
                            ]
                        },
                        "filter": {
                            "type": "object"
                        },
                        "offset": {
                            "type": "integer"
                        },
                        "orderBy": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "required": [
                                    "field"
                                ],
                                "properties": {
                                    "field": {
                                        "type": "string"
                                    },
                                    "order": {
                                        "enum": [
                                            "ASC",
                                            "DESC"
                                        ],
                                        "type": "string"
                                    }
                                }
                            }
                        },
                        "transactionID": {
                            "type": "integer"
                        }
                    }
                }
            }
            
        }'::jsonb);
--} 9 DTOJsonSchema

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

--{ 11 User
SELECT reclada_object.create_subclass('{
    "GUID":"db0db7c0-9b25-4af0-8013-d2d98460cfff",
    "class": "RecladaObject",
    "attributes": {
        "newClass": "User",
        "properties": {
            "login": {"type": "string"}
        },
        "required": ["login"]
    }
}'::jsonb);

    select reclada_object.create('{
            "GUID": "db0789c1-1b4e-4815-b70c-4ef060e90884",
            "class": "User",
            "attributes": {
                "login": "dev"
            }
        }'::jsonb);
--} 11 User

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

--{ 16 ObjectDisplay
SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "ObjectDisplay",
        "$defs": {
            "displayType": {
                "properties": {
                    "orderColumn": {
                        "items": {
                            "type": "string"
                        },
                        "type": "array"
                    },
                    "orderRow": {
                        "items": {
                            "patternProperties": {
                                "^{.*}$": {
                                    "enum": [
                                        "ASC",
                                        "DESC"
                                    ],
                                    "type": "string"
                                }
                            },
                            "type": "object"
                        },
                        "type": "array"
                    }
                },
                "required": [
                    "orderColumn",
                    "orderRow"
                ],
                "type": "object"
            }
        },
        "properties": {
            "caption": {
                "type": "string"
            },
            "card": {
                "$ref": "#/$defs/displayType"
            },
            "classGUID": {
                "type": "string",
                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"
            },
            "flat": {
                "type": "bool"
            },
            "list": {
                "$ref": "#/$defs/displayType"
            },
            "preview": {
                "$ref": "#/$defs/displayType"
            },
            "table": {
                "$ref": "#/$defs/displayType"
            }
        },
        "required": [
            "classGUID",
            "caption"
        ]
    }
}'::jsonb);

    SELECT reclada_object.create(('{
        "GUID": "db09dd42-f2a2-4e34-90ea-a6e5f5ea6dff",
        "class": "ObjectDisplay",
        "attributes": {
            "card": {
                "orderRow": [
                    {
                        "{attributes,name}:string": "ASC"
                    },
                    {
                        "{attributes,mimeType}:string": "DESC"
                    }
                ],
                "orderColumn": [
                    "{attributes,name}:string",
                    "{attributes,mimeType}:string",
                    "{attributes,tags}:array",
                    "{status}:string",
                    "{createdTime}:string",
                    "{transactionID}:number"
                ]
            },
            "list": {
                "orderRow": [
                    {
                        "{attributes,name}:string": "ASC"
                    },
                    {
                        "{attributes,mimeType}:string": "DESC"
                    }
                ],
                "orderColumn": [
                    "{attributes,name}:string",
                    "{attributes,mimeType}:string",
                    "{attributes,tags}:array",
                    "{status}:string",
                    "{createdTime}:string",
                    "{transactionID}:number"
                ]
            },
            "table": {
                "orderRow": [
                    {
                        "{attributes,name}:string": "ASC"
                    },
                    {
                        "{attributes,mimeType}:string": "DESC"
                    }
                ],
                "orderColumn": [
                    "{attributes,name}:string",
                    "{attributes,mimeType}:string",
                    "{attributes,tags}:array",
                    "{status}:string",
                    "{createdTime}:string",
                    "{transactionID}:number"
                ],
                "{GUID}:string": {
                    "width": 250,
                    "caption": "GUID",
                    "displayCSS": "GUID"
                },
                "{status}:string": {
                    "width": 250,
                    "caption": "Status",
                    "displayCSS": "status"
                },
                "{createdTime}:string": {
                    "width": 250,
                    "caption": "Created time",
                    "displayCSS": "createdTime"
                },
                "{transactionID}:number": {
                    "width": 250,
                    "caption": "Transaction",
                    "displayCSS": "transactionID"
                },
                "{attributes,tags}:array": {
                    "items": {
                        "class": "e12e729b-ac44-45bc-8271-9f0c6d4fa27b",
                        "behavior": "preview",
                        "displayCSS": "link"
                    },
                    "width": 250,
                    "caption": "Tags",
                    "displayCSS": "arrayLink"
                },
                "{attributes,name}:string": {
                    "width": 250,
                    "caption": "File name",
                    "behavior": "preview",
                    "displayCSS": "name"
                },
                "{attributes,checksum}:string": {
                    "width": 250,
                    "caption": "Checksum",
                    "displayCSS": "checksum"
                },
                "{attributes,mimeType}:string": {
                    "width": 250,
                    "caption": "Mime type",
                    "displayCSS": "mimeType"
                }
            },
            "caption": "Files",
            "preview": {
                "orderRow": [
                    {
                        "{attributes,name}:string": "ASC"
                    },
                    {
                        "{attributes,mimeType}:string": "DESC"
                    }
                ],
                "orderColumn": [
                    "{attributes,name}:string",
                    "{attributes,mimeType}:string",
                    "{attributes,tags}:array",
                    "{status}:string",
                    "{createdTime}:string",
                    "{transactionID}:number"
                ]
            },
            "classGUID": "'|| (SELECT obj_id
                                FROM reclada.v_class
                                    WHERE for_class = 'File'
                                    ORDER BY ID DESC
                                    LIMIT 1 ) ||'"
        }
    }')::jsonb);

--} 16 ObjectDisplay

--{ 17 View
SELECT reclada_object.create_subclass('{
        "GUID":"db09dcaa-fc90-4760-af68-f855cbe9c2b0",
        "class": "RecladaObject",
        "attributes": {
            "newClass": "View",
            "properties": {
                "name": {"type": "string"},
                "query": {"type": "string"}
            },
            "required": ["name","query"]
        }
    }'::jsonb);
--} 17 View

--{ 18 Function
SELECT reclada_object.create_subclass('{
        "GUID":"db0d8ccd-a06e-46c3-9836-a8b4b68f3cd4",
        "class": "RecladaObject",
        "attributes": {
            "newClass": "Function",
            "$defs": {
                "declare":{
                    "type":"array",
                    "items": {
                        "type": "object",
                        "properties":{
                            "name":{"type": "string"},
                            "type":{
                                "type": "string",
                                "enum": [
                                    "uuid" ,
                                    "jsonb",
                                    "text" ,
                                    "bigint"
                                ]
                            }
                        },
                        "required": ["name","type"]
                    }
                }
            },
            "properties": {
                "name": {"type": "string"},
                "parameters": { "$ref": "#/$defs/declare" },
                "returns": {
                    "type": "string",
                    "enum": [
                        "void",
                        "uuid" ,
                        "jsonb",
                        "text" ,
                        "bigint"
                    ]
                },
                "declare": { "$ref": "#/$defs/declare" },
                "body": {"type": "string"}
            },
            "required": ["name","returns","body"]
        }
    }'::jsonb);
--} 18 Function

--{ 19 DBTriggerFunction
SELECT reclada_object.create_subclass('{
        "GUID":"db0635d4-33be-4b5c-8af4-c90038665b7d",
        "class": "Function",
        "attributes": {
            "newClass": "DBTriggerFunction",
            "properties": {
                "parameters": {
                    "type":"array",
                    "minItems": 1,
                    "maxItems": 1,
                    "items": {
                        "type": "object",
                        "properties":{
                            "name":{
                                "type": "string", 
                                "enum": ["object_id"]
                            },
                            "type":{
                                "type": "string",
                                "enum": ["bigint"]
                            }
                        },
                        "required": ["name","type"]
                    }
                },
                "returns": {
                    "type": "string",
                    "enum": [
                        "void"]
                }
            },
            "required": ["parameters"]
        }
    }'::jsonb);
--} 19 DBTriggerFunction


--{ 20 Trigger
SELECT reclada_object.create_subclass('{
    "GUID":"db05bc71-4f3c-4276-9b97-c9e83f21c813",
    "class": "RecladaObject",
    "attributes": {
        "newClass": "DBTrigger",
        "properties": {
            "name": {"type": "string"},
            "action": {
                "type": "string",
                "enum": [
                    "insert",
                    "delete"
                ]
            },
            "forClasses": {
                "type": "array",
                "items": {"type": "string"}
            },
            "function":{
                "type": "string",
                "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}"
            }
        },
        "required": ["name","action","forClasses","function"]
    }
 }'::jsonb);
--} 20 Trigger