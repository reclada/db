-- version = 18
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "revision",
        "properties": {
            "num": {"type": "number"},
            "user": {"type": "string"},
            "branch": {"type": "string"},
            "dateTime": {"type": "string"}  
        },
        "required": ["dateTime"]
    }
}'::jsonb);


alter table reclada.object
    add column class_guid uuid;


update reclada.object o
    set class_guid = c.obj_id
        from v_class c
            where c.for_class = o.class;

drop VIEW reclada.v_class;
drop VIEW reclada.v_revision;
drop VIEW reclada.v_active_object;
drop VIEW reclada.v_object;
drop VIEW reclada.v_object_status;
drop VIEW reclada.v_user;
alter table reclada.object
    drop column class;

alter table reclada.object
    add column class uuid;

update reclada.object o
    set class = c.class_guid
        from reclada.object c
            where c.id = o.id;

alter table reclada.object
    drop column class_guid;

create index class_index 
    ON reclada.object(class);

\i 'function/public.try_cast_uuid.sql'
\i 'function/reclada_object.get_jsonschema_GUID.sql'
\i 'view/reclada.v_class_lite.sql'
\i 'function/reclada_object.get_GUID_for_class.sql'

delete 
--select *
    from reclada.v_class_lite c
    where c.id = 
        (
            SELECT min(id) min_id
                FROM reclada.v_class_lite
                GROUP BY for_class
                HAVING count(*)>1
        );

select public.raise_exception('find more then 1 version for some class')
    where exists(
        select for_class
            from reclada.v_class_lite
            GROUP BY for_class
            HAVING count(*)>1
    );

UPDATE reclada.object o
    set attributes = c.attributes || '{"version":1}'::jsonb
        from v_class_lite c
            where c.id = o.id;

\i 'view/reclada.v_object_status.sql'
\i 'view/reclada.v_user.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_revision.sql'
\i 'view/reclada.v_class.sql'

\i 'function/reclada_object.get_schema.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada.datasource_insert_trigger_fnc.sql'
\i 'function/reclada_notification.send_object_notification.sql'
\i 'function/reclada_revision.create.sql'
\i 'function/reclada_object.get_schema.sql'



-- проверить, что вернет reclada_object.get_GUID_for_class если есть несколько классов

-- SELECT * FROM reclada.object where class is null;

