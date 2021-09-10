-- version = 20
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/


drop VIEW if exists reclada.v_revision;
drop VIEW if exists reclada.v_active_object;
drop VIEW if exists reclada.v_object;
drop VIEW if exists reclada.v_class_lite;
drop VIEW if exists reclada.v_object_status;
drop VIEW if exists reclada.v_user;
drop VIEW if exists reclada.v_class;

\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_object_status.sql'
\i 'view/reclada.v_user.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'

\i 'view/reclada.v_revision.sql'

\i 'function/reclada_object.get_GUID_for_class.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_notification.send_object_notification.sql'




