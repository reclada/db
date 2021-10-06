-- version = 36
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

DROP VIEW IF EXISTS reclada.v_object_status CASCADE;
DROP VIEW IF EXISTS reclada.v_user CASCADE;
DROP VIEW IF EXISTS reclada.v_class_lite CASCADE;

\i 'view/reclada.v_class_lite.sql'
\i 'view/reclada.v_object_status.sql'
\i 'view/reclada.v_user.sql'


\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_pk_for_class.sql'
\i 'view/reclada.v_import_info.sql'
\i 'view/reclada.v_revision.sql'

\i 'function/reclada_object.refresh_mv.sql'

\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.delete.sql'
