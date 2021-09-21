drop VIEW if EXISTS reclada.v_user;
CREATE OR REPLACE VIEW reclada.v_user
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            obj.attributes->>'login' as login,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class = 'User'
        and status = reclada_object.get_active_status_obj_id();
-- SELECT * from reclada.v_user