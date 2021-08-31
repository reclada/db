-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop VIEW if EXISTS reclada.v_revision;
drop VIEW if EXISTS reclada.v_class;
drop VIEW if EXISTS v_active_object;
--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_class}
--{view/reclada.v_revision}
--{function/api.reclada_object_create}
--{function/api.reclada_object_list}
--{function/api.reclada_object_update}
--{function/api.storage_generate_presigned_post}
--{function/api.storage_generate_presigned_get}
--{function/reclada_notification.send_object_notification}
--{function/reclada_object.cast_jsonb_to_postgres}
--{function/reclada_object.create_subclass}
--{function/reclada_object.create}
--{function/reclada_object.get_query_condition}
--{function/reclada_object.list_add}
--{function/reclada_object.list_drop}
--{function/reclada_object.list_related}
--{function/reclada_object.list}
--{function/reclada_object.update}
--{function/reclada_revision.create}
DROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;
--{function/reclada.datasource_insert_trigger_fnc}
CREATE TRIGGER datasource_insert_trigger
  BEFORE INSERT
  ON reclada.object FOR EACH ROW
  EXECUTE PROCEDURE reclada.datasource_insert_trigger_fnc();

-- PL/pgSQL function dev.downgrade_version() line 25 at EXECUTE
-- SQLSTATE: 2BP01
-- SQLERRM : cannot drop function datasource_insert_trigger_fnc() because other objects depend on it
