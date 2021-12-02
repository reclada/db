/*
 * Function reclada_object.datasource_insert updates defaultDataSet and creates Job object
 * Added instead of reclada.datasource_insert_trigger_fnc function called by trigger.
 * class_name is the name of class inserted in reclada.object.
 * obj_id is GUID of added object.
 * attributes is attributes of added object.
 * Required parameters:
 *  _class_name - the class of objects
 *  obj_id     - GUID of object
 *  attributes - attributes of added object
 */
 DROP FUNCTION IF EXISTS reclada_object.datasource_insert;
CREATE OR REPLACE FUNCTION reclada_object.datasource_insert
(
    _class_name text,
    _obj_id     uuid,
    attributes jsonb
)
RETURNS void AS $$
DECLARE
    dataset_guid  uuid;
    uri           text;
    environment   varchar;
    rel_cnt       int;
    dataset2ds_type text;
BEGIN
    IF _class_name in 
            ('DataSource','File') THEN

        IF (_obj_id IS NULL) THEN
            RAISE EXCEPTION 'Object GUID IS NULL';
        END IF;

        dataset2ds_type := 'defaultDataSet to DataSource';

        SELECT v.obj_id
        FROM reclada.v_active_object v
	    WHERE v.attrs->>'name' = 'defaultDataSet'
	        INTO dataset_guid;

        IF (dataset_guid IS NULL) THEN
            RAISE EXCEPTION 'Can''t found defaultDataSet';
        END IF;

        SELECT count(*)
        FROM reclada.v_active_object
        WHERE class_name = 'Relationship'
            AND NULLIF(attrs->>'object','')::uuid   = _obj_id
            AND NULLIF(attrs->>'subject','')::uuid  = dataset_guid
            AND attrs->>'type'                      = dataset2ds_type
                INTO rel_cnt;

        IF rel_cnt=0 THEN
            PERFORM reclada_object.create(
                format('{
                    "class": "Relationship",
                    "attributes": {
                        "type": "%s",
                        "object": "%s",
                        "subject": "%s"
                        }
                    }', dataset2ds_type, _obj_id, dataset_guid)::jsonb);

        END IF;

        uri := attributes->>'uri';

        SELECT attrs->>'Environment'
        FROM reclada.v_active_object
        WHERE class_name = 'Context'
        ORDER BY id DESC
        LIMIT 1
            INTO environment;

        PERFORM reclada_object.create(
            format('{
                "class": "Job",
                "attributes": {
                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",
                    "status": "new",
                    "type": "%s",
                    "command": "./run_pipeline.sh",
                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
                    }
                }', environment, uri, _obj_id)::jsonb);

    END IF;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;
