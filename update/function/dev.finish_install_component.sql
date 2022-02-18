
DROP FUNCTION IF EXISTS dev.finish_install_component;
CREATE OR REPLACE FUNCTION dev.finish_install_component()
RETURNS text AS $$
DECLARE
    _f_name   text := 'dev.finish_install_component';
    _comp_obj jsonb;
    _data     jsonb;
    _deleted  bigint[];
    _created  bigint[];
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
        into _comp_obj;

    delete from dev.component;

    update dev.component_object
        set status = 'delete'
            where status = 'need to check';

    SELECT array_agg(id_object)
        FROM dev.component_object o
            WHERE status in ('delete','update')
        INTO _deleted;

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
                (_comp_obj ->>'GUID')::uuid ,
                (cr.v ->>'GUID')::uuid ,
                '{}'::jsonb            ,
                (_comp_obj  ->>'GUID')::uuid
            )
            from (select reclada_object.create_subclass(_data)#>'{0}' v) cr;
    END LOOP;

    perform reclada_object.create_relationship(
                'data of reclada-component',
                (_comp_obj     ->>'GUID')::uuid ,
                (el.value ->>'GUID')::uuid ,
                '{}'::jsonb                ,
                (_comp_obj     ->>'GUID')::uuid
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
                where o.guid = (_comp_obj->>'GUID')::uuid
    ) then
        perform reclada_object.update(_comp_obj);
    else
        perform reclada_object.create(_comp_obj);
    end if;
    
    perform reclada_object.refresh_mv('All');

    update dev.component_object u
        set id_object = o.id_object
        from dev.component_object co
        join reclada.v_component_object o
            on (
                o.obj_data#>>'{GUID}' = co.data#>>'{GUID}' 
                and (
                    (
                        co.status = 'create' 
                        and co.id_object is null
                    ) 
                    or (
                        co.status = 'update' 
                        and co.id_object is not null
                    )
                )
            ) or (
                co.status = 'create_subclass'
                and o.obj_data#>>'{attributes,forClass}' = co.data#>>'{attributes,newClass}'
                and o.class_name = 'jsonschema'
                and co.id_object is null
            )
            where co.id = u.id;

    SELECT array_agg(id_object)
        FROM dev.component_object o
            WHERE status in ('create','update','create_subclass')
        INTO _created;

    update reclada.object u
        set attributes = u.attributes || jsonb_build_object('created',to_jsonb(_created),'deleted',to_jsonb(_deleted))
        from reclada.v_component c
        where c.id = u.id
            and u.guid = (_comp_obj->>'GUID')::uuid;

    return 'OK';

END;
$$ LANGUAGE PLPGSQL VOLATILE;
