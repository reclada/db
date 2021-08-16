drop VIEW if EXISTS reclada.v_class;
CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            obj.attrs->>'forClass' as for_class,
            obj.revision_num  ,
            obj.status        ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.data
	FROM reclada.v_active_object obj
   	WHERE class = 'jsonschema';
--select * from reclada.v_class