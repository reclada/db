drop VIEW if EXISTS reclada.v_class;
CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            cl.for_class      ,
            cl.version        ,
            obj.revision_num  ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.status        ,
            obj.data          ,
            obj.parent_guid   ,
            obj.default_value
	FROM reclada.v_class_lite cl
    JOIN reclada.v_active_object obj
        on cl.id = obj.id;
--select * from reclada.v_class