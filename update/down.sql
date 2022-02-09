-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


--{ REC-564

--{function/reclada_object.create}
--{function/reclada_object.create_relationship}
--{function/reclada_object.get_parent_guid}
--{view/reclada.v_component_object}
--{view/reclada.v_relationship}
--{view/reclada.v_component}

    delete from reclada.object 
        where parent_guid in (  '7534ae14-df31-47aa-9b46-2ad3e60b4b6e',
                                '38d35ba3-7910-4e6e-8632-13203269e4b9',
                                'b17500cb-e998-4f55-979b-2ba1218a3b45'
                            );

    delete from reclada.object 
        where class in (select reclada_object.get_GUID_for_class('Component'));

    delete from reclada.object 
        where guid in (select reclada_object.get_GUID_for_class('Component'));
    
    delete from reclada.object 
        where class in (select reclada_object.get_GUID_for_class('Index'));
    
    delete from reclada.object 
        where guid in (select reclada_object.get_GUID_for_class('Index'));
--} REC-564


--{ REC-594

--{view/reclada.v_filter_mapping}

DROP VIEW reclada.v_revision;
DROP VIEW reclada.v_import_info;
DROP VIEW reclada.v_dto_json_schema;
DROP VIEW reclada.v_class;
DROP VIEW reclada.v_task;
DROP VIEW reclada.v_object_display;
DROP VIEW reclada.v_active_object;
--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_object_display}
--{view/reclada.v_task}
--{view/reclada.v_class}
--{view/reclada.v_dto_json_schema}
--{view/reclada.v_import_info}
--{view/reclada.v_revision}

--} REC-594


--{ REC-562

--{function/reclada_object.create_subclass}
--{function/reclada_object.update}
--{function/reclada_object.create}
--{function/reclada_object.list}
--{function/reclada.validate_json_schema}
--{function/reclada.get_validation_schema}
--{function/reclada_object.get_schema}

--} REC-562

--{ REC-564
drop table dev.component;
drop table dev.component_object;
--{function/reclada_object.datasource_insert}
--{function/reclada_object.object_insert}
--{function/reclada_object.delete}
--{function/dev.begin_install_component}
--{function/dev.finish_install_component}
--} REC-564