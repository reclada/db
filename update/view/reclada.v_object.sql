drop VIEW if EXISTS reclada.v_object;
CREATE OR REPLACE VIEW reclada.v_object
AS
with t as (
    SELECT  
            obj.id      ,
            obj.obj_id  ,
            obj.class   ,
            r.num       ,
            NULLIF(obj.attributes ->> 'revision','')::uuid 
                as revision,
            obj.attributes as attrs,
            obj.status  ,
            obj.created_time ,
            obj.created_by   
        FROM reclada.object obj
        left join 
        (
            select  (r.attributes->'num')::bigint num,
                    r.obj_id
                from reclada.object r
                    where class = 'revision'
        ) r
            on r.obj_id = NULLIF(obj.attributes ->> 'revision','')::uuid
)
    SELECT  
            t.id                 ,
            t.obj_id             ,
            t.class              ,
            t.num       as revision_num     ,
            os.caption  as status_caption   ,
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
                    "attributes": %s
                }',
                t.obj_id    ,
                t.class     ,
                coalesce('"' || t.revision::text || '"','null')  ,
                os.caption  ,
                t.attrs
            )::jsonb as data, 
            u.login as login_created_by,
            t.created_by as created_by,
            t.status             
        FROM t
        left join reclada.v_object_status os
            on t.status = os.obj_id
        left join reclada.v_user u
            on u.obj_id = t.created_by
            ;

-- select * from reclada.v_object where revision is not null
-- select distinct status from reclada.object 
-- select obj_id from reclada.v_object_status 


