-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--{function/reclada_object.create}
--{function/reclada_object.update}
--{function/reclada_object.merge}
--{function/reclada_object.list}
--{view/reclada.v_ui_active_object}

--{view/reclada.v_object_unifields}

ALTER SEQUENCE IF EXISTS reclada.object_id_seq CACHE 1;
