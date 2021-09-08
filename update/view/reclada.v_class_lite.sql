drop VIEW if EXISTS reclada.v_class_lite;
CREATE OR REPLACE VIEW reclada.v_class_lite
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            obj.attributes->>'forClass' as for_class,
            obj.attributes->'version'   as version  ,
            obj.created_time  ,
            obj.attributes    ,
            obj.status        
	FROM reclada.object obj
   	WHERE class = reclada_object.get_jsonschema_GUID();
--select * from reclada.v_class_lite