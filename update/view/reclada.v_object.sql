-- drop VIEW if EXISTS reclada.v_object;
CREATE OR REPLACE VIEW reclada.v_object
AS
with t as (
    SELECT  
            obj.id      ,
            obj.GUID    ,
            obj.class   ,
            r.num       ,
            NULLIF(obj.attributes ->> 'revision','')::uuid 
                as revision,
            obj.attributes,
            obj.status  ,
            obj.created_time ,
            obj.created_by   ,
            obj.transaction_id
        FROM reclada.object obj
        left join 
        (
            select  (r.attributes->>'num')::bigint num,
                    r.GUID 
                from reclada.object r
                    where class in (select reclada_object.get_GUID_for_class('revision'))
        ) r
            on r.GUID = NULLIF(obj.attributes ->> 'revision','')::uuid
)
    SELECT  
            t.id                 ,
            t.GUID as obj_id     ,
            t.class              ,
            t.num       as revision_num     ,
            os.caption  as status_caption   ,
            t.revision           ,
            t.created_time       ,
            t.attributes as attrs,
            cl.for_class as class_name,
            (
                select json_agg(tmp)->0
                    FROM 
                    (
                        SELECT  t.GUID       as "GUID"    ,
                                t.class      as class     ,
                                os.caption   as status    ,
                                t.attributes as attributes,
                                t.transaction_id as "transactionID"
                    ) as tmp
            )::jsonb as data,
            u.login as login_created_by,
            t.created_by as created_by,
            t.status,
            t.transaction_id
        FROM t
        left join reclada.v_object_status os
            on t.status = os.obj_id
        left join reclada.v_user u
            on u.obj_id = t.created_by
        left join reclada.v_class_lite cl
            on cl.obj_id = t.class
            ;

-- select * from reclada.v_object where revision is not null
-- select distinct status from reclada.object 
-- select obj_id from reclada.v_object_status 


