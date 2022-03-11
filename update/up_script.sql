-- version = 50
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

-----------
\i 'view/reclada.v_ui_active_object.sql'
\i 'view/reclada.v_component_object.sql'

\i 'function/reclada_object.create_job.sql'
\i 'function/api.storage_generate_presigned_post.sql'
\i 'function/dev.begin_install_component.sql'
\i 'function/dev.finish_install_component.sql'

alter table dev.component add parent_component_name text;