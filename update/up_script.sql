-- version = 19
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

alter table reclada.object
    add column GUID uuid;

update reclada.object o
    set GUID = c.obj_id
        from reclada.object c
            where c.id = o.id;


drop VIEW reclada.v_class;
drop VIEW reclada.v_revision;
drop VIEW reclada.v_active_object;
drop VIEW reclada.v_object;
drop VIEW reclada.v_class_lite;
drop VIEW reclada.v_object_status;
drop VIEW reclada.v_user;
alter table reclada.object
    drop column obj_id;

create index GUID_index 
    ON reclada.object(GUID);

-- delete from reclada.object where class is null;
alter table reclada.object 
    alter column class set not null;

\i 'function/reclada_object.get_jsonschema_GUID.sql'
\i 'view/reclada.v_class_lite.sql'
\i 'view/reclada.v_object_status.sql'
\i 'view/reclada.v_user.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_revision.sql'
\i 'function/reclada.datasource_insert_trigger_fnc.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.delete.sql'
\i 'function/reclada_object.list.sql'

\i 'function/reclada_object.list_add.sql'
\i 'function/reclada_object.list_drop.sql'
\i 'function/reclada_object.list_related.sql'

\i 'function/api.reclada_object_delete.sql'
\i 'function/api.reclada_object_list_add.sql'
\i 'function/api.reclada_object_list_drop.sql'
\i 'function/api.reclada_object_list_related.sql'
\i 'function/api.reclada_object_update.sql'
\i 'function/reclada_revision.create.sql'
\i 'function/reclada_notification.send_object_notification.sql'




