-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop VIEW if EXISTS reclada.v_class;
drop VIEW if EXISTS reclada.v_revision;
drop VIEW if EXISTS reclada.v_active_object;
--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_revision}
--{view/reclada.v_class}
