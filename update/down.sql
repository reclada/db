-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_pk_for_class;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;


--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.parse_filter}
--{function/api.reclada_object_list}
--{function/reclada_object.list}
--{view/reclada.v_filter_mapping}

--{function/reclada_object.datasource_insert}
--{function/reclada_object.create}
--{function/reclada_object.create_subclass}
--{function/reclada_object.get_condition_array}
--{function/reclada_object.update}

DROP INDEX IF EXISTS reclada.parent_guid_index;
ALTER TABLE reclada.object DROP COLUMN IF EXISTS parent_guid;

--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_class}
--{view/reclada.v_pk_for_class}
--{view/reclada.v_import_info}
--{view/reclada.v_revision}

DROP INDEX IF EXISTS reclada.class_lite_obj_idx;
DROP INDEX IF EXISTS reclada.class_lite_class_idx;


DO $$
DECLARE
	rltshp_uuid TEXT;
	dds_uuid	uuid;
	dds_rev		uuid;
	dds_revn	int;
	rlt_cnt		int;
BEGIN
	SELECT obj_id,attrs->>'revision', revision_num
	FROM reclada.v_active_object vao 
	WHERE attrs->>'name' = 'defaultDataSet'
		INTO dds_uuid, dds_rev, dds_revn;

	SELECT count(*)
	FROM reclada.v_active_object vao
	WHERE class_name ='Relationship' AND attrs ->>'type'= 'defaultDataSet to DataSource' and (attrs->>'subject')::uuid=dds_uuid
		INTO rlt_cnt;
	
	IF rlt_cnt>0 THEN
		DELETE FROM reclada.object
		WHERE guid = dds_uuid AND status = reclada_object.get_active_status_obj_id();

		DELETE FROM reclada.object
		WHERE guid = dds_rev;

		UPDATE reclada.object
		SET status = reclada_object.get_active_status_obj_id()
		WHERE status = reclada_object.get_archive_status_obj_id()
			AND id = (
				SELECT id
				FROM reclada.v_object
				WHERE obj_id = dds_uuid
					AND revision_num = dds_revn - 1
			);

		DELETE FROM reclada.OBJECT 
		WHERE class=(
			SELECT obj_id 
			FROM v_class  
			WHERE for_class ='Relationship'
		)
			AND ATTRIBUTES->>'type' = 'defaultDataSet to DataSource';
	END IF;
END
$$;
