drop VIEW if EXISTS reclada.v_import_info;
CREATE OR REPLACE VIEW reclada.v_import_info
AS
    SELECT  obj.id            ,
            obj.obj_id        as guid,
            (obj.attrs->>'tranID')::bigint as tran_id,
            obj.attrs->>'name'        as name   ,
            obj.revision_num  ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.status        ,
            obj.data
	FROM reclada.v_active_object obj
   	WHERE class_name = 'ImportInfo';
--select * from reclada.v_import_info
