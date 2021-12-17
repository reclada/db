drop VIEW if EXISTS reclada.v_ui_active_object;
CREATE OR REPLACE VIEW reclada.v_ui_active_object
AS
with recursive 
d as ( 
    select  data, 
            obj_id
        FROM reclada.v_active_object obj 
),
t as
(
    SELECT  je.key,
            jsonb_typeof(je.value) typ,
            d.obj_id,
            je.value
        from d 
        JOIN LATERAL jsonb_each(d.data) je
            on true
        where jsonb_typeof(je.value) != 'null'
    union
    SELECT 
            d.key ||','|| je.key as key ,
            jsonb_typeof(je.value) typ,
            d.obj_id,
            je.value
        from (
            select  d.data -> t.key as data, 
                    t.key,
                    d.obj_id
            from d 
            join t
                on t.typ = 'object'
        ) d
        JOIN LATERAL jsonb_each(d.data) je
            on true
        where jsonb_typeof(je.value) != 'null'
),
res as
(
    select  t.obj_id,
            jsonb_object_agg
            (
                '{'||t.key||'}',
                t.value
            ) as data,
            array_agg(
                '{'||t.key||'}:'||t.typ 
            ) as display_key
        from t 
            where t.typ != 'object'
            group by t.obj_id
)
select  res.obj_id          , 
        res.data            ,
        res.display_key     ,
        t.id                ,
        t.class             ,
        t.revision_num      ,
        t.status            ,
        t.status_caption    ,
        t.revision          ,
        t.created_time      ,
        t.class_name        ,
        t.attrs             ,
        t.transaction_id    ,
        t.parent_guid
    from res
    join reclada.v_active_object t
        on t.obj_id = res.obj_id
;
-- select * from reclada.v_ui_active_object limit 300
