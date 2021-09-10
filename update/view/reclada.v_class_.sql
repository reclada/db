drop VIEW if EXISTS reclada.v_class;
CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            obj.attrs->>'forClass' as for_class,
            (obj.attrs->>'version')::bigint as version,
            obj.revision_num  ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.status        ,
            obj.data
	FROM reclada.v_active_object obj
   	WHERE class_name = 'jsonschema';
--select * from reclada.v_class

drop VIEW if EXISTS reclada.v_class_lite;
CREATE OR REPLACE VIEW reclada.v_class_lite
AS
    SELECT  obj.id,
            obj.GUID as obj_id,
            obj.attributes->>'forClass' as for_class,
            (attributes->>'version')::bigint as version,
            obj.created_time,
            obj.attributes as attrs,
            obj.status
	FROM reclada.object obj
   	WHERE class = reclada_object.get_jsonschema_GUID();
--select * from reclada.v_class_lite