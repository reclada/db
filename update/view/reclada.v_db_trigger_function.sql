drop VIEW if EXISTS reclada.v_db_trigger_function;
CREATE OR REPLACE VIEW reclada.v_db_trigger_function
AS
    SELECT  vo.obj_id as function_guid,
            vo.data #>> '{attributes,name}' as function_name
        FROM reclada.v_active_object vo 
            WHERE vo.class_name = 'DBTriggerFunction';