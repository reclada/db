-- не грохаю, чтобы не поломать триггер
CREATE OR REPLACE FUNCTION reclada.datasource_insert_trigger_fnc()
RETURNS trigger AS $$
DECLARE
    obj_id         uuid;
    dataset       jsonb;
    uri           text;

BEGIN
    -- IF NEW.data IS NULL THEN
    --     RAISE EXCEPTION 'data cannot be null';
    -- END IF;

    IF (NEW.class = 'DataSource') THEN

        obj_id := NEW.obj_id;

        SELECT (reclada_object.list(format('{
            "class": "DataSet",
            "attrs": {
                "name": "defaultDataSet"
                }
            }')::jsonb)) -> 0
        INTO dataset;

        dataset := jsonb_set(dataset, '{attrs, dataSources}', dataset->'attrs'->'dataSources' || format('["%s"]', obj_id)::jsonb);

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
                }', uri, obj_id)::jsonb);

    END IF;

RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';