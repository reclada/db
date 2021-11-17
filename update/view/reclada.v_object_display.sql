drop VIEW if EXISTS reclada.v_object_display;
CREATE OR REPLACE VIEW reclada.v_object_display
AS
    SELECT  obj.id            ,
            obj.guid          ,
            (obj.attributes->>'classGUID')::uuid  as class_guid,
            obj.attributes->>'caption'   as caption  ,
            obj.attributes->'table'      as table    ,
            obj.attributes->'card'       as card     ,
            obj.attributes->'preview'    as preview  ,
            obj.attributes->'list'       as list     ,
            obj.created_time  ,
            obj.attributes    ,
            obj.status        
        FROM reclada.object obj
        WHERE class = (select reclada_object.get_GUID_for_class('ObjectDisplay'))
            AND status = reclada_object.get_active_status_obj_id()
;
--select * from reclada.v_object_display
