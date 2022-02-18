-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

--{function/dev.begin_install_component}
--{function/dev.finish_install_component}
--{function/dev.downgrade_version}
--{view/reclada.v_object_display}
drop VIEW reclada.v_component_object;
--{view/reclada.v_component}
--{view/reclada.v_component_object}

alter table dev.component_object
    drop column id_object;

    delete from reclada.object 
        where guid in 
        (
            SELECT relationship_guid 
                FROM reclada.v_component_object 
                    where class_name in (   'jsonschema', 
                                            'DataSet',
                                            'User',
                                            'DTOJsonSchema',
                                            'ObjectDisplay',
                                            'Message'
                                        )
                        and component_name = 'db'
        );

    -- delete from reclada.object 
    --     where class in (select reclada_object.get_GUID_for_class('Index'));

