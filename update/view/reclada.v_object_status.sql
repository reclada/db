drop VIEW if EXISTS reclada.v_object_status;
CREATE OR REPLACE VIEW reclada.v_object_status
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            obj.attributes->>'caption' as caption,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class = 'ObjectStatus'
--        and status = reclada_object.get_active_status_obj_id();
-- SELECT * from reclada.v_object_status