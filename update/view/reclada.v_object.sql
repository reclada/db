-- drop VIEW if EXISTS reclada.v_object;
CREATE OR REPLACE VIEW reclada.v_object
AS
    SELECT  
            t.id            ,
            t.GUID as obj_id,
            t.class         ,
            (
                SELECT  (r.attributes ->> 'num')::bigint num
                    FROM reclada.object r
                        WHERE r.class IN (SELECT reclada_object.get_guid_for_class('revision'))
                            AND r.guid = NULLIF(t.attributes ->> 'revision', '')::uuid
                            LIMIT 1
            ) AS revision_num,
            os.caption  as status_caption   ,
            NULLIF(t.attributes ->> 'revision', '')::uuid AS revision,
            t.created_time       ,
            t.attributes as attrs,
            cl.for_class as class_name,
            (
                select json_agg(tmp)->0
                    FROM 
                    (
                        SELECT  t.GUID       as "GUID"              ,
                                t.class      as "class"             ,
                                os.caption   as "status"            ,
                                t.attributes as "attributes"        ,
                                t.transaction_id as "transactionID" ,
                                t.parent_guid as "parentGUID"       ,
                                t.created_by  as "createdBy"        ,
                                t.created_time as "createdTime"
                    ) as tmp
            )::jsonb as data,
            u.login as login_created_by,
            t.created_by as created_by,
            t.status,
            t.transaction_id,
            t.parent_guid
        FROM reclada.object t
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


