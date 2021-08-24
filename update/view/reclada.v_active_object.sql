drop VIEW if EXISTS reclada.v_active_object;
CREATE OR REPLACE VIEW reclada.v_active_object
AS
    SELECT  
            t.id                ,
            t.obj_id            ,
            t.class             ,
            t.revision_num      ,
            t.status            ,
            t.status_caption    ,
            t.revision          ,
            t.created_time      ,
            t.attrs             ,
            t.data 
        FROM reclada.v_object as t
            -- объект не удален
            where t.status = reclada_object.get_active_status_obj_id()
            ;

-- select * from reclada.v_object limit 300
-- select * from reclada.object