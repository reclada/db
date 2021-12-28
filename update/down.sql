-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop table reclada.draft;

--{function/api.reclada_object_create}
--{function/api.reclada_object_list}
--{function/api.reclada_object_delete}
--{function/api.reclada_object_update}

--{function/reclada_object.create}
--{function/reclada_object.datasource_insert}
--{function/reclada_object.list}
--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.parse_filter}

--{function/reclada.raise_exception}
--{view/reclada.v_filter_avaliable_operator}
--{function/reclada_object.create_subclass}
--{view/reclada.v_ui_active_object}
--{view/reclada.v_default_display}

delete from reclada.object 
    where guid in (select reclada_object.get_GUID_for_class('Asset'));

delete from reclada.object 
    where guid in (select reclada_object.get_GUID_for_class('DBAsset'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,object,minLength}'
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,subject,minLength}'
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));

DROP OPERATOR IF EXISTS reclada.##(boolean, boolean);
CREATE OPERATOR reclada.# (
    FUNCTION = reclada.xor,
    LEFTARG = boolean,
    RIGHTARG = boolean
);

    
with g as 
(
    select g.obj_id
    from
    (
        select s.obj_id, count(*) cnt
            from reclada.v_DTO_json_schema s
            join reclada.v_object o
                on o.obj_id = s.obj_id
                where s.function = 'reclada_object.list'
                    group by s.obj_id
    ) as g
    left join lateral 
    (
        select reclada.raise_exception('reclada_object.list has more 2 DTO schema')
            where g.cnt > 2
    ) ex  on true
)
update reclada.object o
    set status = reclada_object.get_active_status_obj_id()
    from g
        where g.obj_id = o.guid;

delete from reclada.object 
    where id =
    (
        SELECT max(id)
            FROM reclada.v_object 
                where class_name = 'DTOJsonSchema' 
                    and attrs->>'function' = 'reclada_object.list' 
    );