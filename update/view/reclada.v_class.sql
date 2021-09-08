drop VIEW if EXISTS reclada.v_class;
CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            obj.attrs->>'forClass' as for_class,
            (obj.attrs->'version')::bigint as for_class,
            obj.revision_num  ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.status        ,
            obj.data
	FROM reclada.v_active_object obj
   	WHERE class in (select reclada_object.get_GUID_for_class('jsonschema'));
--select * from reclada.v_class