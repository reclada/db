-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop table reclada.unique_object_reclada_object;
drop table reclada.unique_object;
drop table reclada.field;

--{function/reclada_object.create}
--{function/reclada_object.get_schema}
--{view/reclada.v_ui_active_object}
--{function/reclada_object.update}
--{function/reclada_object.list}
--{function/reclada.update_unique_object}
--{function/reclada.random_string}
--{function/api.reclada_object_list}
--{view/reclada.v_filter_mapping}

--{ REC-564
    delete from reclada.object 
        where class in (select reclada_object.get_GUID_for_class('Component'));

    delete from reclada.object 
        where guid in (select reclada_object.get_GUID_for_class('Component'));
--}