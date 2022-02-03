
DROP FUNCTION IF EXISTS dev.finish_install_component;
CREATE OR REPLACE FUNCTION dev.finish_install_component()
RETURNS void AS $$
DECLARE
    _f_name   text := 'dev.finish_install_component';
    _obj      jsonb;
BEGIN
    perform reclada.raise_exception('Component does not found.',_f_name)
        where not exists(select 1 from dev.component);
    
    select ('{
                "GUID": "' || guid::text || '",
                "class":"Component",
                "attributes": {
                    "name":"' || name || '",
                    "repository":"' || repository || '",
                    "commitHash":"' || commit_hash  || '"
                }
            }')::jsonb
        from dev.component
        into _obj;
        
    delete from dev.component;

    if exists
    (
        select 
            from reclada.object o
            join dev.component c
                on c.guid = o.guid
    ) then
        perform reclada_object.update(_obj);
    else
        perform reclada_object.create(_obj);
    end if;


    update dev.component_object
        set status = 'delete'
            where status = 'need to check';

    perform reclada_object.delete(data)
        from dev.component_object
            where status = 'delete';

    perform reclada_object.update(data)
        from dev.component_object
            where status = 'update';

    perform reclada_object.create_relationship(
                'data of reclada-component',
                (_obj     ->>'GUID')::uuid ,
                (el.value ->>'GUID')::uuid ,
                '{}'::jsonb                ,
                (_obj     ->>'GUID')::uuid
            )
        from dev.component_object c
        cross join lateral (
            select reclada_object.create(c.data) v
        ) cr
        cross join lateral jsonb_array_elements(cr.v) el
            where c.status = 'create';
    
END;
$$ LANGUAGE PLPGSQL VOLATILE;