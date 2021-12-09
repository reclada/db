-- version = 39
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/api.reclada_object_list.sql'
\i 'function/reclada_object.parse_filter.sql'
\i 'function/reclada_object.get_query_condition_filter.sql'
\i 'function/reclada_object.list.sql'
\i 'view/reclada.v_filter_mapping.sql'

ALTER TABLE reclada.object ADD COLUMN IF NOT EXISTS parent_guid uuid;
CREATE INDEX IF NOT EXISTS parent_guid_index ON reclada.object USING btree (parent_guid);

\i 'function/reclada_object.update.sql'
\i 'function/reclada_object.datasource_insert.sql'
\i 'function/reclada_object.create.sql'
\i 'function/reclada_object.create_subclass.sql'
\i 'view/reclada.v_object.sql'
\i 'view/reclada.v_active_object.sql'
\i 'view/reclada.v_class.sql'
\i 'function/reclada_object.get_condition_array.sql'

CREATE INDEX IF NOT EXISTS class_lite_obj_idx ON reclada.v_class_lite USING btree (obj_id);
CREATE INDEX IF NOT EXISTS class_lite_class_idx ON reclada.v_class_lite USING btree (for_class);

DO $$
DECLARE
	dsrc_uuid	TEXT;
	dset_uuid	TEXT;
	trn_id		INT;
	dset_data	jsonb;

BEGIN
	SELECT v.obj_id, v.data
    FROM reclada.v_active_object v
    WHERE v.attrs->>'name' = 'defaultDataSet'
	    INTO dset_uuid, dset_data;
	FOR dsrc_uuid IN (	SELECT DISTINCT jsonb_array_elements_text(attrs->'dataSources') 
						FROM reclada.v_active_object vao 
						WHERE obj_id = dset_uuid::uuid) LOOP
		PERFORM reclada_object.create(
            format('{
                "class": "Relationship",
                "attributes": {
                    "type": "defaultDataSet to DataSource",
                    "object": "%s",
                    "subject": "%s"
                    }
                }', dsrc_uuid, dset_uuid)::jsonb);
	END LOOP;
	IF (jsonb_array_length(dset_data->'attributes'->'dataSources') > 0 )  THEN
		dset_data := jsonb_set(dset_data, '{attributes, dataSources}', '[]'::jsonb);
		PERFORM reclada_object.update(dset_data);
	END IF;
END
$$;

