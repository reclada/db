CREATE MATERIALIZED VIEW reclada.v_class_lite
AS
    SELECT  obj.id,
            obj.GUID as obj_id,
            obj.attributes->>'forClass' as for_class,
            (attributes->>'version')::bigint as version,
            obj.created_time,
            reclada.get_validation_schema(obj.GUID) as validation_schema,
            obj.attributes,
            obj.status        
	FROM reclada.object obj
   	WHERE obj.class = reclada_object.get_jsonschema_GUID();
--select * from reclada.v_class_lite
ANALYZE reclada.v_class_lite;

