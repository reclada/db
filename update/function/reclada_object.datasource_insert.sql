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
    _dataset2ds_type text = 'defaultDataSet to DataSource';
    _f_name text = 'reclada_object.datasource_insert';
BEGIN
    IF _class_name in ('DataSource','File') THEN

        _uri := attributes->>'uri';

        SELECT v.obj_id
        FROM reclada.v_active_object v
        WHERE v.class_name = 'DataSet'
            and v.attrs->>'name' = 'defaultDataSet'
        INTO _dataset_guid;        
        IF (_dataset_guid IS NULL) THEN
            RAISE EXCEPTION 'Can''t found defaultDataSet';
        END IF;
        PERFORM reclada_object.create_relationship(_dataset2ds_type, _obj_id, _dataset_guid);
        IF _uri LIKE '%inbox/jobs/%' THEN
            PERFORM reclada_object.create_job(_uri, _obj_id);
        ELSE
            
            SELECT data 
                FROM reclada.v_active_object
                    WHERE class_name = 'PipelineLite'
                        LIMIT 1
                INTO _pipeline_lite;
            _new_guid := public.uuid_generate_v4();
            IF _uri LIKE '%inbox/pipelines/%/%' THEN
                
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
                IF _pipeline_job_guid IS NULL THEN
                    perform reclada.raise_exception('PIPELINE_JOB_GUID not found',_f_name);
                END IF;
                
                SELECT  data #>> '{attributes,inputParameters,0,uri}',
                        (data #>> '{attributes,inputParameters,1,dataSourceId}')::uuid
                    FROM reclada.v_active_object o
                        WHERE o.obj_id = _pipeline_job_guid
                    INTO _uri, _obj_id;

            ELSE
                SELECT data 
                    FROM reclada.v_active_object o
                        WHERE o.class_name = 'Task'
                            AND o.obj_id = (_pipeline_lite #>> '{attributes,tasks,0}')::uuid
                    INTO _task;
                IF _task IS NOT NULL THEN
                    _pipeline_job_guid := _new_guid;
                END IF;
            END IF;
            
            PERFORM reclada_object.create_job(
                _uri,
                _obj_id,
                _new_guid,
                _task->>'GUID',
                _task-> 'attributes' ->>'command',
                _pipeline_job_guid
            );
        END IF;
    END IF;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;
