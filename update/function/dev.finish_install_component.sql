
DROP FUNCTION IF EXISTS dev.finish_install_component;
CREATE OR REPLACE FUNCTION dev.finish_install_component()
RETURNS text AS $$
DECLARE
    _f_name   text := 'dev.finish_install_component';
    _obj      jsonb;
    _data     jsonb;
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

    update dev.component_object
        set status = 'delete'
            where status = 'need to check';

    perform reclada_object.delete(data)
        from dev.component_object
            where status = 'delete';

    FOR _data IN (SELECT data 
                    from dev.component_object 
                        where status = 'create_subclass'
                        ORDER BY id)
    LOOP
        perform reclada_object.create_relationship(
                'data of reclada-component',
                (_obj ->>'GUID')::uuid ,
                (cr.v ->>'GUID')::uuid ,
                '{}'::jsonb            ,
                (_obj  ->>'GUID')::uuid
            )
            from (select reclada_object.create_subclass(_data)#>'{0}' v) cr;
    END LOOP;

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

    perform reclada_object.update(data)
        from dev.component_object
            where status = 'update';

    if exists
    (
        select 
            from reclada.object o
                where o.guid = (_obj->>'GUID')::uuid
    ) then
        perform reclada_object.update(_obj);
    else
        perform reclada_object.create(_obj);
    end if;
    
    perform reclada_object.refresh_mv('All');

    return 'OK';

END;
$$ LANGUAGE PLPGSQL VOLATILE;
