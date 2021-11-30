-- version = 43
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

create table reclada.draft(
    id bigint NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1),
    guid uuid,
    user_guid uuid DEFAULT reclada_object.get_default_user_obj_id(),
    data jsonb not null
);


\i 'function/api.reclada_object_create.sql'
\i 'function/api.reclada_object_list.sql'
\i 'function/api.reclada_object_delete.sql'
\i 'function/api.reclada_object_update.sql'

\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.datasource_insert.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada_object.parse_filter.sql'

\i 'function/reclada.raise_exception.sql'
\i 'view/reclada.v_filter_avaliable_operator.sql'
\i 'view/reclada.v_default_display.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'view/reclada.v_ui_active_object.sql'



SELECT reclada_object.create_subclass('{
    "class": "DataSource",
    "attributes": {
        "newClass": "Asset"
    }
}'::jsonb);

SELECT reclada_object.create_subclass('{
    "class": "Asset",
    "attributes": {
        "newClass": "DBAsset"
    }
}'::jsonb);


UPDATE reclada.OBJECT
SET ATTRIBUTES = jsonb_set(ATTRIBUTES,'{schema,properties,object,minLength}','36'::jsonb)
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = jsonb_set(ATTRIBUTES,'{schema,properties,subject,minLength}','36'::jsonb)
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));


DROP OPERATOR IF EXISTS reclada.#(boolean, boolean);
CREATE OPERATOR reclada.## (
    FUNCTION = reclada.xor,
    LEFTARG = boolean,
    RIGHTARG = boolean
);

delete from reclada.v_object_display;

SELECT reclada_object.create(('{
    "class":"ObjectDisplay",
    "attributes":{
        "classGUID": "'|| reclada_object.get_GUID_for_class('File') ||'",
        "caption": "Files",
        "table": {
            "{attributes,name}:string": {
                "caption": "File name",
                "displayCSS": "name",
                "width": 250,
                "behavior":"preview"
            },
            "{attributes,tags}:array": {
                "caption": "Tags",
                "displayCSS": "arrayLink",
                "width": 250,
                "items": {
                    "displayCSS": "link",
                    "behavior": "preview",
                    "class":"'|| reclada_object.get_GUID_for_class('tag') ||'"
                }
            },
            "{attributes,mimeType}:string": {
                "caption": "Mime type",
                "width": 250,
                "displayCSS": "mimeType"
            },
            "{attributes,checksum}:string": {
                "caption": "Checksum",
                "width": 250,
                "displayCSS": "checksum"
            },
            "{status}:string":{
                "caption": "Status",
                "width": 250,
                "displayCSS": "status"
            },
            "{createdTime}:string":{
                "caption": "Created time",
                "width": 250,
                "displayCSS": "createdTime"
            },
            "{transactionID}:number":{
                "caption": "Transaction",
                "width": 250,
                "displayCSS": "transactionID"
            },
            "{GUID}:string":{
                "caption": "GUID",
                "width": 250,
                "displayCSS": "GUID"
            },
            "orderRow": [
                {"{attributes,name}:string":"ASC"},
                {"{attributes,mimeType}:string":"DESC"}
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
        "card":{
            "orderRow": [
                {"{attributes,name}:string":"ASC"},
                {"{attributes,mimeType}:string":"DESC"}
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
        "preview":{
            "orderRow": [
                {"{attributes,name}:string":"ASC"},
                {"{attributes,mimeType}:string":"DESC"}
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
        "list":{
             "orderRow": [
                {"{attributes,name}:string":"ASC"},
                {"{attributes,mimeType}:string":"DESC"}
            ],
            "orderColumn": [
                "{attributes,name}:string",
                "{attributes,mimeType}:string",
                "{attributes,tags}:array",
                "{status}:string",
                "{createdTime}:string",
                "{transactionID}:number"
            ]
        }
    }
}')::jsonb);

DO
$do12$
DECLARE
	_guid uuid;
    _json jsonb;
BEGIN
	select obj_id
        from reclada.v_DTO_json_schema 
            where function = 'reclada_object.list'
            into _guid;
    _json := '{
        "status": "active",
        "attributes": {
            "schema": {
                "type": "object",
                "anyOf": [
                    {
                        "required": [
                            "transactionID","class"
                        ]
                    },
                    {
                        "required": [
                            "class"
                        ]
                    },
                    {
                        "required": [
                            "filter","class"
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
            },
            "function": "reclada_object.list"
        },
        "parentGUID": null,
        "createdTime": "2021-11-08T11:01:49.274513+00:00",
        "transactionID": 61
    }';
    
    _json := _json || ('{"GUID": "'||_guid::text||'"}')::jsonb;
    select reclada_object.get_guid_for_class('DTOJsonSchema')
        into _guid;
    _json := _json || ('{"class": "' ||_guid::text|| '"}')::jsonb;
    perform reclada_object.update(_json);
    
END
$do12$;

