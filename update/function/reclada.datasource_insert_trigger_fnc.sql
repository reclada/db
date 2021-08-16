CREATE OR REPLACE FUNCTION reclada.datasource_insert_trigger_fnc()
RETURNS trigger AS $$
DECLARE
    objid         uuid;
    dataset       jsonb;
    uri           text;

BEGIN
    IF NEW.data IS NULL THEN
        RAISE EXCEPTION 'data cannot be null';
    END IF;

    IF (NEW.data->>'class' = 'DataSource') OR (NEW.data->>'class' = 'File') THEN

        objid := NEW.data->>'id';

        SELECT v.data
        FROM reclada.v_object v
	    WHERE v.data->'attrs'->>'name' = 'defaultDataSet'
	    INTO dataset;

        dataset := jsonb_set(dataset, '{attrs, dataSources}', dataset->'attrs'->'dataSources' || format('["%s"]', objid)::jsonb);

        PERFORM reclada_object.update(dataset);

        uri := NEW.data->'attrs'->>'uri';

        PERFORM reclada_object.create(
            format('{
                "class": "Job",
                "attrs": {
                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",
                    "status": "new",
                    "type": "K8S",
                    "command": "./run_pipeline.sh",
                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
                    }
                }', uri, objid)::jsonb);

    END IF;

RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';
