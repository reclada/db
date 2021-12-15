drop VIEW if EXISTS reclada.v_task;
CREATE OR REPLACE VIEW reclada.v_task
AS
    SELECT  obj.id            ,
            obj.obj_id              as guid,
            obj.attrs->>'type'      as type,
            obj.attrs->>'command'   as command,
            obj.revision_num  ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.status        ,
            obj.data
	FROM reclada.v_active_object obj
   	WHERE class_name = 'Task';
--select * from reclada.v_task
