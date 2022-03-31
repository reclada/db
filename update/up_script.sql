-- version = 50
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

--{REC 624
CREATE AGGREGATE reclada.jsonb_object_agg(jsonb) (
  SFUNC = 'jsonb_concat',
  STYPE = jsonb,
  INITCOND = '{}'
);

\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada.jsonb_merge.sql'
\i 'function/reclada_object.list.sql'

DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
DROP VIEW IF EXISTS reclada.v_parent_field;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_task;
DROP VIEW IF EXISTS reclada.v_ui_active_object;
DROP VIEW IF EXISTS reclada.v_dto_json_schema;
DROP VIEW IF EXISTS reclada.v_component_object;
DROP VIEW IF EXISTS reclada.v_component;
DROP VIEW IF EXISTS reclada.v_relationship;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_user;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_status;
DROP VIEW IF EXISTS reclada.v_object_display;

\i 'function/reclada_object.get_jsonschema_guid.sql'
\i 'view/reclada.v_class_lite.sql'
\i 'function/reclada_object.get_guid_for_class.sql'
\i 'view/reclada.v_object_status.sql'

\i 'function/reclada_object.delete.sql'
\i 'view/reclada.v_object_display.sql'
\i 'function/reclada_object.need_flat.sql'

\i 'view/reclada.v_user.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_relationship.sql'
\i 'view/reclada.v_component.sql'
\i 'view/reclada.v_component_object.sql'
\i 'view/reclada.v_dto_json_schema.sql'
\i 'view/reclada.v_ui_active_object.sql'
\i 'view/reclada.v_task.sql'
\i 'view/reclada.v_revision.sql'
\i 'view/reclada.v_import_info.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_parent_field.sql'
\i 'view/reclada.v_object_unifields.sql'
--REC 624}
\i 'view/reclada.v_get_duplicates_query.sql'

--{REC 633
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.update.sql'
--REC 633}