-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

------

alter table dev.component drop column parent_component_name;
--{function/dev.finish_install_component}
--{function/dev.begin_install_component}

--{view/reclada.v_ui_active_object}
--{view/reclada.v_component_object}
--{function/reclada_object.create_job}
--{function/api.storage_generate_presigned_post}