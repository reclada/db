-- version = 43
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

SELECT reclada_object.create('{
    "class": "jsonschema",
    "attributes":{
        "forClass":"ObjectDisplay",
        "version": "1",
        "schema":{
            "$defs": {
                "displayType":{
                    "type": "object",
                    "properties": {
                        "orderColumn":{
                            "type": "array",
                            "items":{
                                "type": "string"
                            }
                        },
                        "orderRow":{
                            "type": "array",
                            "items":{
                                "type": "object",
                                "patternProperties": {
                                    "^{.*}$": {
                                        "type": "string",
                                        "enum": ["ASC", "DESC"]
                                    }
                                }
                            }
                        }
                    },
                    "required":["orderColumn","orderRow"]
                }
            },
            "properties": {
                "classGUID": {"type": "string"},
                "caption": {"type": "string"},
                "flat": {"type": "bool"},
                "table":{"$ref": "#/$defs/displayType"},
                "card":{"$ref": "#/$defs/displayType"},
                "preview":{"$ref": "#/$defs/displayType"},
                "list":{"$ref": "#/$defs/displayType" }
            },
            "required": ["classGUID","caption"]
        }
    }
}'::jsonb);

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('ObjectDisplay') ||'",
        "caption": "Object display"
    }
}')::jsonb);

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('DataRow') ||'",
        "caption": "Data row"
    }
}')::jsonb);

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('TextBlock') ||'",
        "caption": "Text block"
    }
}')::jsonb);

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('Message') ||'",
        "caption": "Message"
    }
}')::jsonb);
SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('Page') ||'",
        "caption": "Page"
    }
}')::jsonb);
SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('Document') ||'",
        "caption": "Document"
    }
}')::jsonb);

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('jsonschema') ||'",
        "caption": "Json schema"
    }
}')::jsonb);

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('Job') ||'",
        "caption": "Job"
    }
}')::jsonb);

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('File') ||'",
        "caption": "Files",
        "table": {
            "{attributes,name}": {
                "caption": "File name",
                "displayCSS": "name",
                "width": 250,
                "behavior":"preview"
            },
            "{attributes,tags}": {
                "caption": "Tags",
                "displayCSS": "arrayLink",
                "width": 250,
                "items": {
                    "displayCSS": "link",
                    "behavior": "preview",
                    "class":"'|| reclada_object.get_GUID_for_class('tag') ||'"
                }
            },
            "{attributes,mimeType}": {
                "caption": "Mime type",
                "width": 250,
                "displayCSS": "mimeType"
            },
            "{attributes,checksum}": {
                "caption": "Checksum",
                "width": 250,
                "displayCSS": "checksum"
            },
            "{status}":{
                "caption": "Status",
                "width": 250,
                "displayCSS": "status"
            },
            "{createdTime}":{
                "caption": "Created time",
                "width": 250,
                "displayCSS": "createdTime"
            },
            "{transactionID}":{
                "caption": "Transaction",
                "width": 250,
                "displayCSS": "transactionID"
            },
            "orderRow": [
                {"{attributes,name}":"ASC"},
                {"{attributes,mimeType}":"DESC"}
            ],
            "orderColumn": [
                "{attributes,name}",
                "{attributes,mimeType}",
                "{attributes,tags}",
                "{status}",
                "{createdTime}",
                "{transactionID}"
            ]
        },
        "card":{
            "orderRow": [
                {"{attributes,name}":"ASC"},
                {"{attributes,mimeType}":"DESC"}
            ],
            "orderColumn": [
                "{attributes,name}",
                "{attributes,mimeType}",
                "{attributes,tags}",
                "{status}",
                "{createdTime}",
                "{transactionID}"
            ]
        },
        "preview":{
            "orderRow": [
                {"{attributes,name}":"ASC"},
                {"{attributes,mimeType}":"DESC"}
            ],
            "orderColumn": [
                "{attributes,name}",
                "{attributes,mimeType}",
                "{attributes,tags}",
                "{status}",
                "{createdTime}",
                "{transactionID}"
            ]
        },
        "list":{
            "orderRow": [
                {"{attributes,name}":"ASC"},
                {"{attributes,mimeType}":"DESC"}
            ],
            "orderColumn": [
                "{attributes,name}",
                "{attributes,mimeType}",
                "{attributes,tags}",
                "{status}",
                "{createdTime}",
                "{transactionID}"
            ]
        }
    }
}')::jsonb);

\i 'view/reclada.v_object_display.sql' 
\i 'view/reclada.v_ui_active_object.sql' 
\i 'function/reclada_object.need_flat.sql' 
\i 'function/reclada_object.list.sql' 
\i 'function/api.reclada_object_update.sql' 
\i 'function/reclada_object.update.sql' 
\i 'function/api.reclada_object_list.sql' 
\i 'function/api.reclada_object_create.sql' 
\i 'function/api.reclada_object_delete.sql' 

\i 'function/api.storage_generate_presigned_get.sql'
\i 'function/api.storage_generate_presigned_post.sql'

*/