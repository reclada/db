DROP FUNCTION IF EXISTS reclada_object.create_job;
CREATE OR REPLACE FUNCTION reclada_object.create_job
(
    _uri            text,
    _obj_id         uuid,
    _new_guid       uuid    DEFAULT NULL,
    _task_guid      text    DEFAULT NULL,
    _task_command   text    DEFAULT NULL,
    _pipeline_job_guid  uuid    DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
    func_name       text := 'reclada_object.create_job';
    _environment    text;
    _obj            jsonb;
BEGIN
    SELECT attrs->>'Environment'
        FROM reclada.v_active_object
        WHERE class_name = 'RuntimeContext'
        ORDER BY created_time DESC
        LIMIT 1
        INTO _environment;

    IF _obj_id IS NULL THEN
        PERFORM reclada.raise_exception('Object ID is blank.', func_name);
    END IF;

    _obj := format('{
                "class": "Job",
                "attributes": {
                    "task": "%s",
                    "status": "new",
                    "command": "%s",
                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
                    }
                }',
                    COALESCE(reclada.try_cast_uuid(_task_guid), 'c94bff30-15fa-427f-9954-d5c3c151e652'::uuid),
                    COALESCE(_task_command,'./run_pipeline.sh'),
                    _uri,
                    _obj_id::text
            )::jsonb;
    IF _new_guid IS NOT NULL THEN
        _obj := jsonb_set(_obj,'{GUID}',format('"%s"',_new_guid)::jsonb);
    END IF;

    _obj := jsonb_set(_obj,'{attributes,type}',format('"%s"',_environment)::jsonb);

    IF _pipeline_job_guid IS NOT NULL THEN
        _obj := jsonb_set(_obj,'{attributes,inputParameters}',_obj#>'{attributes,inputParameters}' || format('{"PipelineLiteJobGUID" :"%s"}',_pipeline_job_guid)::jsonb);
    END IF;
    RETURN reclada_object.create(_obj);
END;
$$ LANGUAGE 'plpgsql' VOLATILE;