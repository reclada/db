-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

    delete from reclada.object 
        where guid in 
        (
            SELECT relationship_guid 
                FROM reclada.v_component_object 
                    where class_name = 'jsonschema'
                        and component_name = 'db'
        );

    -- delete from reclada.object 
    --     where class in (select reclada_object.get_GUID_for_class('Index'));

