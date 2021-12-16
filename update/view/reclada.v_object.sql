-- drop VIEW if EXISTS reclada.v_object;
CREATE OR REPLACE VIEW reclada.v_object
AS  SELECT t.id,
    t.guid AS obj_id,
    t.class,
    (SELECT (r_1.attributes ->> 'num'::text)::bigint
    FROM reclada.OBJECT r_1
    WHERE guid = NULLIF(t.attributes ->> 'revision'::text, ''::text)::uuid
    	AND r_1.class IN ( SELECT reclada_object.get_guid_for_class('revision'::text) AS get_guid_for_class)) AS revision_num,
    os.caption AS status_caption,
    NULLIF(t.attributes ->> 'revision'::text, ''::text)::uuid AS revision,
    t.created_time,
    t.attributes AS attrs,
    cl.for_class AS class_name,
    (( SELECT json_agg(tmp.*) -> 0
           FROM ( SELECT t.guid AS "GUID",
                    t.class,
                    os.caption AS status,
                    t.attributes,
                    t.transaction_id AS "transactionID",
                    t.parent_guid AS "parentGUID",
                    t.created_time AS "createdTime") tmp))::jsonb AS data,
    u.login AS login_created_by,
    t.created_by,
    t.status,
    t.transaction_id,
    t.parent_guid
   FROM reclada.OBJECT t
   	 LEFT JOIN v_class_lite cl ON cl.obj_id = t.class
     LEFT JOIN v_object_status os ON t.status = os.obj_id
     LEFT JOIN v_user u ON u.obj_id = t.created_by;

-- select * from reclada.v_object where revision is not null
-- select distinct status from reclada.object 
-- select obj_id from reclada.v_object_status 


