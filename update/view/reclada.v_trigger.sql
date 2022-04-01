drop VIEW if EXISTS reclada.v_trigger;
CREATE OR REPLACE VIEW reclada.v_trigger
AS
    SELECT  vo.obj_id as trigger_guid,
            (vo.data #>> '{attributes,function}')::uuid as function_guid,
            vo.data #>> '{attributes, action}' as trigger_type,
            vo.data #> '{attributes, forClasses}' as for_classes
        FROM reclada.v_active_object vo 
            WHERE vo.class_name = 'DBTrigger';

