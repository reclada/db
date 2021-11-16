-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

--{view/reclada.v_ui_active_object}
--{view/reclada.v_object_display}
delete from reclada.object 
    where class in (select reclada_object.get_GUID_for_class('ObjectDisplay'));

delete from reclada.object 
    where guid in (select reclada_object.get_GUID_for_class('ObjectDisplay'));

--{function/reclada_object.list}
--{function/reclada_object.update}
--{function/api.reclada_object_update}
--{function/api.reclada_object_list}
--{function/api.reclada_object_create}
--{function/reclada_object.need_flat}
