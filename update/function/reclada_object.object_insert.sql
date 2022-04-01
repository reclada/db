/*
 * Function reclada_object.object_insert updates defaultDataSet and creates Job object
 * Added instead of reclada.datasource_insert_trigger_fnc function called by trigger.
 * class_name is the name of class inserted in reclada.object.
 * obj_id is GUID of added object.
 * attributes is attributes of added object.
 * Required parameters:
 *  _class_name - the class of objects
 *  obj_id     - GUID of object
 *  attributes - attributes of added object
 */
 DROP FUNCTION IF EXISTS reclada_object.object_insert;
CREATE OR REPLACE FUNCTION reclada_object.object_insert
(
    _class_name text,
    _obj_id     uuid,
    attributes jsonb
)
RETURNS void AS $$
DECLARE
    _exec_text          text ;
    _where              text ;
    _fields             text ;

    _pipeline_lite      jsonb;
    _task               jsonb;
    _dataset_guid       uuid ;
    _new_guid           uuid ;
    _pipeline_job_guid  uuid ;
    _stage              text ;
    _uri                text ;
    _dataset2ds_type    text = 'defaultDataSet to DataSource';
    _f_name             text = 'reclada_object.object_insert';
    _trigger_guid       uuid;
    _function_name      text;
    _function_guid      uuid;
    _query              text;
    _current_id         bigint;               
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
    
    ELSIF _class_name = 'Index' then
        _exec_text := 'DROP INDEX IF EXISTS reclada.#@#@#name#@#@#;
            CREATE INDEX #@#@#name#@#@# ON reclada.object USING #@#@#method#@#@# (#@#@#fields#@#@#) #@#@#where#@#@#;';
        _exec_text := REPLACE(_exec_text, '#@#@#name#@#@#'   , attributes->>'name'                      );
        _exec_text := REPLACE(_exec_text, '#@#@#method#@#@#' , coalesce(attributes->>'method' ,'btree') );

        _fields :=  (
                        select string_agg(value,'#@#@#sep#@#@#')
                            from jsonb_array_elements_text(attributes->'fields')
                    );
        _where := coalesce(attributes->>'wherePredicate','');

        if _where != '' then
            if _where = 'IS NOT NULL' then
                _where := REPLACE(_fields,'#@#@#sep#@#@#', ' IS NOT NULL OR ') || ' IS NOT NULL';
            end if;
            _where := 'WHERE ' || _where;
        end if;

        _fields := REPLACE(_fields,'#@#@#sep#@#@#', ' , ');

        _exec_text := REPLACE(_exec_text, '#@#@#fields#@#@#' , _fields);
        _exec_text := REPLACE(_exec_text, '#@#@#where#@#@#'  , _where );
        EXECUTE _exec_text;

    ELSIF _class_name = 'View' then

        _exec_text := 'DROP VIEW IF EXISTS reclada.#@#@#name#@#@#;
            CREATE VIEW reclada.#@#@#name#@#@# as #@#@#query#@#@#;';
        _exec_text := REPLACE(_exec_text, '#@#@#name#@#@#'   , attributes->>'name' );
        _exec_text := REPLACE(_exec_text, '#@#@#query#@#@#' , attributes->>'query' );

        EXECUTE _exec_text;

    ELSIF _class_name IN ('Function', 'DBTriggerFunction') then

        _exec_text := 'DROP FUNCTION IF EXISTS reclada.#@#@#name#@#@#;
            CREATE FUNCTION reclada.#@#@#name#@#@#
            (
                #@#@#parameters#@#@#
            )
            RETURNS #@#@#returns#@#@# AS '||chr(36)||chr(36)||'
            DECLARE
                #@#@#declare#@#@#
            BEGIN   
                #@#@#body#@#@#
            END;
            '||chr(36)||chr(36)||' LANGUAGE ''plpgsql'' VOLATILE;';

        _exec_text := REPLACE(_exec_text, '#@#@#name#@#@#'      , attributes->>'name'   );
        _exec_text := REPLACE(_exec_text, '#@#@#returns#@#@#'   , attributes->>'returns');
        _exec_text := REPLACE(_exec_text, '#@#@#body#@#@#'      , attributes->>'body'   );

        _exec_text := REPLACE(
                _exec_text, '#@#@#parameters#@#@#', 
                (SELECT  STRING_AGG(
                            (el.value->>'name')
                                || ' '
                                || (el.value->>'type'),
                            ',' || chr(10)
                        )
                    FROM jsonb_array_elements(attributes->'parameters') el) 
            );

        _exec_text := REPLACE(
                _exec_text, '#@#@#declare#@#@#', 
                (SELECT  STRING_AGG(
                            (el.value->>'name')
                                || ' '
                                || (el.value->>'type')
                                || ';', 
                            chr(10)
                        )
                    FROM jsonb_array_elements(attributes->'declare') el )
            );

        EXECUTE _exec_text;
    END IF;
    SELECT vc.obj_id
        FROM reclada.v_class vc
            WHERE vc.for_class = 'DBTrigger'
        INTO _trigger_guid;

    SELECT vab.id 
        FROM reclada.v_active_object vab
            WHERE vab.obj_id = _obj_id
        INTO _current_id;
    
    SELECT string_agg(sbq.subquery, '')
	    FROM ( 
            SELECT  'SELECT reclada.' 
                    || vtf.function_name 
                    || '(' 
                    || _current_id 
                    || ');'
                    || chr(10) AS subquery
                FROM reclada.v_trigger vt
                    JOIN reclada.v_db_trigger_function vtf
                    ON vt.function_guid = vtf.function_guid
                        WHERE vt.trigger_type = 'insert'
                            AND _class_name IN (SELECT jsonb_array_elements_text(vt.for_classes))
            ) sbq
        INTO _query;

    IF _query IS NOT NULL THEN
        raise notice '(%)', _query;
        EXECUTE _query;
    END IF;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;
