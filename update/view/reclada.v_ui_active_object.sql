drop VIEW if EXISTS reclada.v_ui_active_object;
CREATE OR REPLACE VIEW reclada.v_ui_active_object
AS
    SELECT  t.id                ,
            t.obj_id            ,
            t.class             ,
            t.revision_num      ,
            t.status            ,
            t.status_caption    ,
            t.revision          ,
            t.created_time      ,
            t.class_name        ,
            t.attrs             ,
            j.data              ,
            t.transaction_id    ,
            t.parent_guid
        FROM reclada.v_active_object t
        join
        (
            SELECT  t.id,
                    jsonb_object_agg(t.key, t.val) as data
                    FROM 
                    (
                        SELECT  t.id,
                                j.key,
                                t.data #>> j.key::text[] val
                            FROM reclada.v_active_object t
                            JOIN reclada.v_object_display od
                                ON od.class_guid = t.class
                            JOIN lateral 
                            (
                                SELECT key FROM jsonb_each(od.table)
                                UNION SELECT '{GUID}'
                            ) j 
                                ON j.key LIKE '{%}'
                    ) t
                    GROUP BY t.id
        ) j
            on t.id = j.id
;
-- select * from reclada.v_ui_active_object limit 300
