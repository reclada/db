-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


UPDATE reclada.object
SET attributes = attributes - 'parentField'
WHERE guid='7f56ece0-e780-4496-8573-1ad4d800a3b6' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = attributes - 'parentField'
WHERE guid='f5bcc7ad-1a9b-476d-985e-54cf01377530' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = attributes - 'parentField'
WHERE guid='3ed1c180-a508-4180-9281-2f9b9a9cd477' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = attributes - 'parentField'
WHERE guid='85d32073-4a00-4df7-9def-7de8d90b77e0' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = attributes - 'parentField'
WHERE guid='7643b601-43c2-4125-831a-539b9e7418ec' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = attributes - 'dupBehavior'
WHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = attributes - 'isCascade'
WHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' and status = reclada_object.get_active_status_obj_id();

UPDATE reclada.object
SET attributes = attributes - 'dupChecking'
WHERE guid='c7fc0455-0572-40d7-987f-583cc2c9630c' and status = reclada_object.get_active_status_obj_id();

--{view/reclada.v_parent_field}
--{view/reclada.v_unifields_idx_cnt}
--{view/reclada.v_unifields_pivoted}
DROP MATERIALIZED VIEW       reclada.v_object_unifields;

--{function/reclada.get_unifield_index_name}
--{function/reclada_object.merge}
--{function/reclada.get_children}
--{function/reclada.get_duplicates}
--{function/reclada_object.add_cr_dup_mark}
--{function/reclada_object.update_json_by_guid}
--{function/reclada_object.update_json}
--{function/reclada_object.remove_parent_guid}
--{function/reclada_object.get_parent_guid}

--{function/reclada_object.get_query_condition_filter}
--{view/reclada.v_pk_for_class}
--{function/reclada_object.create}
--{function/reclada_object.create_subclass}
--{function/reclada_object.delete}
--{function/reclada_object.refresh_mv}
--{function/reclada_object.update}
--{function/reclada_object.datasource_insert}
--{function/reclada_object.parse_filter}
--{function/reclada_object.list}


--{function/reclada_object.list}
--{function/reclada_object.get_query_condition_filter}
--{function/api.reclada_object_create}
--{function/reclada_object.delete}

--{view/reclada.v_filter_avaliable_operator}
--{view/reclada.v_ui_active_object}

DROP TABLE reclada_object.cr_dup_behavior;
DROP TYPE reclada.dp_bhvr;

DROP INDEX reclada.uri_index_;
DROP INDEX reclada.checksum_index_;
