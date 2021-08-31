-- version = 9
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/
drop VIEW if EXISTS reclada.v_revision;
drop VIEW if EXISTS reclada.v_class;
drop VIEW if EXISTS v_active_object;
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_revision.sql'

\i 'function/api.reclada_object_create.sql'
\i 'function/api.reclada_object_list.sql'
\i 'function/api.reclada_object_update.sql'
\i 'function/api.storage_generate_presigned_post.sql'
\i 'function/api.storage_generate_presigned_get.sql'
\i 'function/reclada_notification.send_object_notification.sql'
\i 'function/reclada_object.cast_jsonb_to_postgres.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.get_query_condition.sql'
\i 'function/reclada_object.list_add.sql'
\i 'function/reclada_object.list_drop.sql'
\i 'function/reclada_object.list_related.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_revision.create.sql'
\i 'function/reclada.datasource_insert_trigger_fnc.sql'