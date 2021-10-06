DROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite CASCADE;
CREATE MATERIALIZED VIEW reclada.v_class_lite
AS
    SELECT  obj.id,
            obj.GUID as obj_id,
            obj.attributes->>'forClass' as for_class,
            (attributes->>'version')::bigint as version,
            obj.created_time,
            obj.attributes,
            obj.status        
	FROM reclada.object obj
   	WHERE class = reclada_object.get_jsonschema_GUID();
--select * from reclada.v_class_lite