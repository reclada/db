-- version = 44
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

CREATE TYPE reclada.dp_bhvr AS ENUM ('Replace','Update','Reject','Copy','Insert','Merge');

CREATE TABLE reclada_object.cr_dup_behavior (
    parent_guid     uuid,
    transaction_id  int8,
    dup_behavior    reclada.dp_bhvr,
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

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"table"'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('Cell')) and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"page"'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('Table')) and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"document"'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('Page')) and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"fileGUID"'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('Document')) and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{parentField}','"table"'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('DataRow')) and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{dupBehavior}','"Replace"'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('File')) and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{isCascade}','true'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('File')) and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = jsonb_set(attributes,'{dupChecking}','[{"uniFields" : ["uri"], "isMandatory" : true}, {"uniFields" : ["checksum"], "isMandatory" : true}]'::jsonb)
WHERE guid IN (SELECT reclada_object.get_guid_for_class('File')) and status = reclada_object.get_active_status_obj_id();

SELECT reclada_object.refresh_mv('uniFields');


CREATE INDEX uri_index_ ON reclada.object USING HASH (((attributes->'uri')));
CREATE INDEX checksum_index_ ON reclada.object USING HASH (((attributes->'checksum')));
