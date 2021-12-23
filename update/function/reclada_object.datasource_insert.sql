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

    _pipeline_lite jsonb;
    _task  jsonb;
    _dataset_guid  uuid;
    _new_guid  uuid;
    _pipeline_job_guid  uuid;
    _stage         text;
    _uri           text;
    _environment   varchar;
    _rel_cnt       int;
    _dataset2ds_type text = 'defaultDataSet to DataSource';
    _f_name text = 'reclada_object.datasource_insert';
    dataset_guid  uuid;
    uri           text;
    environment   varchar;
    rel_cnt       int;
    dataset2ds_type text:= 'defaultDataSet to DataSource';
BEGIN
    IF _class_name in ('DataSource','File') THEN

        _uri := attributes->>'uri';

        SELECT v.obj_id
        FROM reclada.v_active_object v
        WHERE v.class_name = 'DataSet'
            and v.attrs->>'name' = 'defaultDataSet'
        INTO _dataset_guid;
        PERFORM reclada_object.create_relationship(dataset2ds_type, _obj_id, _dataset_guid);
        SELECT attrs->>'Environment'
            FROM reclada.v_active_object
                WHERE class_name = 'Context'
                ORDER BY created_time DESC
                LIMIT 1
            INTO _environment;
        if _uri like '%inbox/jobs/%' then
        
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
                        }', _environment, _uri, _obj_id
                    )::jsonb
                );
        
        ELSE
            
            SELECT data 
                FROM reclada.v_active_object
                    WHERE class_name = 'PipelineLite'
                        LIMIT 1
                INTO _pipeline_lite;
            _new_guid := public.uuid_generate_v4();
            IF _uri like '%inbox/pipelines/%/%' then
                
                _stage := SPLIT_PART(
                                SPLIT_PART(_uri,'inbox/pipelines/',2),
                                '/',
                                2
                            );
                _stage = replace(_stage,'.json','');
                SELECT data 
                    FROM reclada.v_active_object o
                        where o.class_name = 'Task'
                            and o.obj_id = (_pipeline_lite #>> ('{attributes,tasks,'||_stage||'}')::text[])::uuid
                    into _task;
                
                _pipeline_job_guid = reclada.try_cast_uuid(
                                        SPLIT_PART(
                                            SPLIT_PART(_uri,'inbox/pipelines/',2),
                                            '/',
                                            1
                                        )
                                    );
                if _pipeline_job_guid is null then 
                    perform reclada.raise_exception('PIPELINE_JOB_GUID not found',_f_name);
                end if;
                
                SELECT  data #>> '{attributes,inputParameters,0,uri}',
                        (data #>> '{attributes,inputParameters,1,dataSourceId}')::uuid
                    from reclada.v_active_object o
                        where o.obj_id = _pipeline_job_guid
                    into _uri, _obj_id;

            ELSE
                SELECT data 
                    FROM reclada.v_active_object o
                        where o.class_name = 'Task'
                            and o.obj_id = (_pipeline_lite #>> '{attributes,tasks,0}')::uuid
                    into _task;
                _pipeline_job_guid := _new_guid;
            END IF;
            
            PERFORM reclada_object.create(
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
                        _task->>'GUID',
                        _environment, 
                        _task-> 'attributes' ->>'command',
                        _uri,
                        _obj_id,
                        _pipeline_job_guid::text
                )::jsonb
            );
        IF (dataset_guid IS NULL) THEN
            RAISE EXCEPTION 'Can''t found defaultDataSet';
        END IF;
    END IF;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;
