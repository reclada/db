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
\i 'function/reclada_object.create.sql'
\i 'function/api.reclada_object_list.sql'
\i 'function/api.reclada_object_delete.sql'
\i 'function/reclada_object.datasource_insert.sql'
\i 'function/reclada.raise_exception.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'

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


UPDATE reclada.OBJECT
SET ATTRIBUTES = jsonb_set(ATTRIBUTES,'{schema,properties,object,minLength}','36'::jsonb)
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = jsonb_set(ATTRIBUTES,'{schema,properties,subject,minLength}','36'::jsonb)
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));
