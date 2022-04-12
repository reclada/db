drop VIEW if EXISTS reclada.v_ui_active_object;
CREATE OR REPLACE VIEW reclada.v_ui_active_object
AS
select 
'with recursive 
d as ( 
    select  data, 
            obj_id,
            created_time,
            attrs 
        FROM reclada.v_active_object obj 
            where #@#@#where#@#@#
                OFFSET #@#@#offset#@#@#
                LIMIT #@#@#limit#@#@#
),
t as
(
    SELECT  je.key,
            1 as q,
            jsonb_typeof(je.value) typ,
            d.obj_id,
            je.value
        from d 
        JOIN LATERAL jsonb_each(d.data) je
            on true
        -- where jsonb_typeof(je.value) != ''null''
    union
    SELECT 
            d.key ||'',''|| je.key as key ,
            d.q,
            jsonb_typeof(je.value) typ,
            d.obj_id,
            je.value
        from (
            select  d.data #> (''{''||t.key||''}'')::text[] as data, 
                    t.q+1 as q,
                    t.key,
                    d.obj_id
            from t 
            join d
                on t.typ = ''object''
        ) d
        JOIN LATERAL jsonb_each(d.data) je
            on true
        -- where jsonb_typeof(je.value) != ''null''
),
res as
(
    select  rr.obj_id,
            rr.data,
            rr.display_key,
            o.attrs,
            o.created_time,
            o.id
        from
        (
            select  t.obj_id,
                    jsonb_object_agg
                    (
                        ''{''||t.key||''}'',
                        t.value
                    ) as data,
                    array_agg(
                        t.key||''#@#@#separator#@#@#''||t.typ 
                    ) as display_key
                from t 
                    where t.typ != ''object''
                    group by t.obj_id
        ) rr
        join reclada.v_active_object o
            on o.obj_id = rr.obj_id
)
' as val
;
-- select * from reclada.v_ui_active_object limit 300
