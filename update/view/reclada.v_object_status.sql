CREATE MATERIALIZED VIEW reclada.v_object_status
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'caption' as caption,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class in (select reclada_object.get_guid_for_class('ObjectStatus'));
--        and status = reclada_object.get_active_status_obj_id();
ANALYZE reclada.v_object_status;