-- drop VIEW if EXISTS reclada.v_active_object;
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
            t.class_name        ,
            t.attrs             ,
            t.data              ,
            t.transaction_id    ,
            t.parent_guid,
            t.default_value
        FROM reclada.v_object as t
            -- object wasn't deleted
            where t.status = reclada_object.get_active_status_obj_id()
;
-- select * from reclada.v_active_object limit 300
-- select * from reclada.object