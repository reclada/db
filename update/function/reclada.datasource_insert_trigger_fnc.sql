CREATE OR REPLACE FUNCTION reclada.datasource_insert_trigger_fnc()
RETURNS trigger AS $$
DECLARE
    obj_id         uuid;
    dataset       jsonb;
    uri           text;

BEGIN
    IF (NEW.class = 'DataSource') OR (NEW.class = 'File') THEN

        obj_id := NEW.obj_id;

        SELECT v.data
        FROM reclada.v_active_object v
	    WHERE v.attrs->>'name' = 'defaultDataSet'
	    INTO dataset;

        dataset := jsonb_set(dataset, '{attributes, dataSources}', dataset->'attributes'->'dataSources' || format('["%s"]', obj_id)::jsonb);

        PERFORM reclada_object.update(dataset);

        uri := NEW.attributes->>'uri';

        PERFORM reclada_object.create(
            format('{
                "class": "Job",
                "attributes": {
                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",
                    "status": "new",
                    "type": "K8S",
                    "command": "./run_pipeline.sh",
                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
                    }
                }', uri, obj_id)::jsonb);

    END IF;

RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';
