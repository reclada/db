-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_pk_for_class;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;

--{function/reclada_object.datasource_insert}
--{function/reclada_object.create}
--{function/reclada_object.create_subclass}
--{function/reclada_object.get_condition_array}

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
	rlt_cnt		int;
BEGIN
	SELECT obj_id
	FROM reclada.v_active_object vao 
	WHERE attrs->>'name' = 'defaultDataSet'
		INTO dds_uuid;

	SELECT count(*)
	FROM reclada.v_active_object vao
	WHERE class_name ='Relationship' AND attrs ->>'type'= 'defaultDataSet to DataSource' and (attrs->>'subject')::uuid=dds_uuid
		INTO rlt_cnt;
	
	IF rlt_cnt>0 THEN
	SELECT reclada_object.UPDATE(b.d) FROM (
			SELECT jsonb_set (a.data,'{attributes, dataSources}',(
				SELECT '['||string_agg('"'||obj_id::TEXT||'"',',')||']'
				FROM v_active_object vao 
				WHERE class_name ='Relationship' AND attrs ->>'type'= 'defaultDataSet to DataSource')
				::jsonb) AS d 
			FROM (
				SELECT DATA 
				FROM v_active_object vao
				WHERE obj_id=dds_uuid)
			a) 
		b;
		FOR rltshp_uuid IN (SELECT obj_id FROM v_active_object vao WHERE class_name ='Relationship' AND attrs ->>'type'= 'defaultDataSet to DataSource') LOOP
			PERFORM reclada_object.delete(
				format('{
					"GUID": "%s"
					}', rltshp_uuid)::jsonb);
		END LOOP;
	END IF;
END
$$;