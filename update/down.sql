-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop table reclada.unique_object_reclada_object;
drop table reclada.unique_object;
drop table reclada.field;

--{function/reclada_object.create}
--{function/reclada_object.get_schema}
--{view/reclada.v_ui_active_object}
