drop VIEW if EXISTS reclada.v_object;
CREATE OR REPLACE VIEW reclada.v_object
AS
/*
    возвращает по все записи из таблицы 
        + добавляет номер ревизии 
        + собирает json
*/
with t as (
    SELECT  
            obj.id      ,
            obj.obj_id  ,
            obj.class   ,
            r.num       ,
            obj.revision,
            obj.attrs   ,
            obj.status  ,
            obj.created_time    
        FROM reclada.object obj
        left join 
        (
            select  (r.attrs->'num')::bigint num,
                    r.obj_id
                from reclada.object r
                    where class = 'revision'
        ) r
            on r.obj_id = obj.revision
)
    SELECT  
            t.id                 ,
            t.obj_id             ,
            t.class              ,
            t.num as revision_num,
            t.status             ,
            os.caption as status_caption ,
            t.revision           ,
            t.created_time       ,
            t.attrs              ,
            format
            (
                '{
                    "id": "%s",
                    "class": "%s",
                    "revision": %s, 
                    "status": "%s",
                    "attrs": %s
                }',
                t.obj_id    ,
                t.class     ,
                coalesce('"' || t.revision::text || '"','null')  ,
                os.caption  ,
                t.attrs
            )::jsonb as data -- собираю json
        FROM t
        join reclada.object_status os
            on t.status = os.id
            ;

-- select * from reclada.v_object limit 300
-- select * from reclada.object