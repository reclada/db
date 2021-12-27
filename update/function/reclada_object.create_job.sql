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
    _task_guid_converted    uuid;
BEGIN
    SELECT attrs->>'Environment'
    FROM reclada.v_active_object
    WHERE class_name = 'Context'
    ORDER BY created_time DESC
    LIMIT 1
        INTO _environment;
    IF COALESCE(_environment, '') = '' THEN
        PERFORM reclada.raise_exception('Environment variable is blank.', func_name);
    END IF;
    IF COALESCE(_uri, '') = '' THEN
        PERFORM reclada.raise_exception('URI variable is blank.', func_name);
    END IF;
    IF _obj_id IS NULL THEN
        PERFORM reclada.raise_exception('Object ID is blank.', func_name);
    END IF;
    _task_guid_converted := reclada.try_cast_uuid(_task_guid);
    IF (_task_guid_converted IS NULL) THEN
        RETURN reclada_object.create(
            format('{
                "class": "Job",
                "attributes": {
                    "task": "c94bff30-15fa-427f-9954-d5c3c151e652",
                    "status": "new",
                    "type": "%s",
                    "command": "./run_pipeline.sh",
                    "inputParameters": [{"uri": "%s"}, {"dataSourceId": "%s"}]
                    }
                }',
                    _environment,
                    _uri,
                    _obj_id::text
            )::jsonb
        );
    ELSE
        IF _new_guid IS NULL THEN
            PERFORM reclada.raise_exception('Job GUID is blank.', func_name);
        END IF;
        IF _pipeline_job_guid IS NULL THEN
            PERFORM reclada.raise_exception('Pipeline Job GUID is blank.', func_name);
        END IF;
        IF COALESCE(_task_command, '') = '' THEN
            PERFORM reclada.raise_exception('Task Command is blank.', func_name);
        END IF;
        RETURN reclada_object.create(
            format('{
                "GUID":"%s",
                "class": "Job",
                "attributes": {
                    "task": "%s",
                    "status": "new",
                    "type": "%s",
                    "command": "%s",
                    "inputParameters": [
                            { "uri"                 :"%s"   }, 
                            { "dataSourceId"        :"%s"   },
                            { "PipelineLiteJobGUID" :"%s"   }
                        ]
                    }
                }',
                    _new_guid::text,
                    _task_guid_converted::text,
                    _environment, 
                    _task_command,
                    _uri,
                    _obj_id::text,
                    _pipeline_job_guid::text
            )::jsonb
        );
    END IF;

    
END;
$$ LANGUAGE 'plpgsql' VOLATILE;