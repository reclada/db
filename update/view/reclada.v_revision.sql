drop VIEW if EXISTS reclada.v_revision;
CREATE OR REPLACE VIEW reclada.v_revision
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            (obj.attrs->>'num')::bigint as num      ,
            obj.attrs->>'branch'        as branch   ,
            obj.attrs->>'user'          as user     ,
            obj.attrs->>'dateTime'      as date_time,
            obj.attrs->>'old_num'       as old_num  ,
            obj.revision_num  ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.status        ,
            obj.data
	FROM reclada.v_active_object obj
   	WHERE class = 'revision';
--select * from reclada.v_revision
