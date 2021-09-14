-- version = 20
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;

\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_class.sql'
\i 'view/reclada.v_revision.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.list.sql'
\i 'function/reclada_object.list_related.sql'

\i 'function/api.storage_generate_presigned_get.sql'
\i 'function/api.storage_generate_presigned_post.sql'
\i 'function/api.reclada_object_list_drop.sql'
\i 'function/api.reclada_object_list_related.sql'



