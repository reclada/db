-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

update reclada.object u
    set transaction_id = m.tran_id
    from (
        select  (data->>'id')::bigint as id  ,
                (data->>'tran_id')::bigint tran_id
            from dev.meta_data
    ) m
    where m.id = u.id;

delete from dev.meta_data where ver = 49;

drop table dev.meta_data;

--{function/dev.begin_install_component}
--{function/dev.finish_install_component}
--{function/dev.downgrade_component}
--{function/reclada_object.create_relationship}
--{function/reclada_object.create_subclass}
--{function/reclada_object.update}

--{function/dev.downgrade_version}
--{view/reclada.v_object_display}
drop VIEW reclada.v_component_object;
--{view/reclada.v_component}
--{view/reclada.v_component_object}

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

