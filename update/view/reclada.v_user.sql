CREATE MATERIALIZED VIEW reclada.v_user
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'login' as login,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class in (select reclada_object.get_GUID_for_class('User')) 
        and status = reclada_object.get_active_status_obj_id();
ANALYZE reclada.v_user;