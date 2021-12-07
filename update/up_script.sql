-- version = 44
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

CREATE TYPE dp_bhvr AS ENUM ('Replace','Update','Reject','Copy','Insert','Merge');

CREATE TABLE reclada_object.cr_dup_behavior (
    parent_guid     uuid,
    transaction_id  int8,
    dup_behavior    dp_bhvr,
    last_use        timestamp DEFAULT current_timestamp,
    PRIMARY KEY     (transaction_id, parent_guid)
);

DROP VIEW reclada.v_pk_for_class;

\i 'view/reclada.v_object_unifields.sql'
\i 'view/reclada.v_parent_field.sql'
\i 'function/reclada.get_unifield_index_name.sql'
\i 'view/reclada.v_unifields_idx_cnt.sql'
\i 'view/reclada.v_unifields_pivoted.sql'

\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada_object.merge.sql'
\i 'function/reclada_object.update_json.sql'
\i 'function/reclada_object.update_json_by_guid.sql'
\i 'function/reclada_object.remove_parent_guid.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.delete.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.refresh_mv.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada.get_childs.sql'
\i 'function/reclada_object.datasource_insert.sql'
\i 'function/reclada.get_duplicates.sql'
\i 'function/reclada_object.add_cr_dup_mark.sql'
\i 'function/reclada_object.parse_filter.sql'

\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/api.reclada_object_create.sql'
\i 'function/reclada_object.delete.sql'

\i 'view/reclada.v_filter_avaliable_operator.sql'

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"table"'::jsonb)
WHERE guid='7f56ece0-e780-4496-8573-1ad4d800a3b6' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"page"'::jsonb)
WHERE guid='f5bcc7ad-1a9b-476d-985e-54cf01377530' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"document"'::jsonb)
WHERE guid='3ed1c180-a508-4180-9281-2f9b9a9cd477' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"fileGUID"'::jsonb)
WHERE guid='85d32073-4a00-4df7-9def-7de8d90b77e0' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"table"'::jsonb)
WHERE guid='7643b601-43c2-4125-831a-539b9e7418ec' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{dupBehavior}','"Update"'::jsonb)
WHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{isCascade}','true'::jsonb)
WHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{dupChecking}','[{"uniFields" : ["uri"], "isMandatory" : true}, {"uniFields" : ["checksum"], "isMandatory" : true}]'::jsonb)
WHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' and status = reclada_object.get_active_status_obj_id();

SELECT reclada_object.refresh_mv('uniFields');


CREATE INDEX uri_index_ ON reclada.object USING HASH (((attributes->'uri')));
CREATE INDEX checksum_index_ ON reclada.object USING HASH (((attributes->'checksum')));
