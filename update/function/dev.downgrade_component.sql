DROP FUNCTION IF EXISTS dev.downgrade_component;
CREATE or replace function dev.downgrade_component( 
    _component_name text
)
returns text
LANGUAGE PLPGSQL VOLATILE
as
$$
BEGIN
    CREATE TEMP TABLE del_comp(
        tran_id bigint,
        id bigint,
        guid uuid,
        name text,
        rev_num bigint
    );

    with recursive t as (
        SELECT  transaction_id, 
                id, 
                guid, 
                name, 
                null as pre, 
                null::bigint as pre_id,
                0 as lvl,
                c.revision_num
            from reclada.v_component c
                WHERE not exists(
                        SELECT 
                            FROM reclada.v_component_object co 
                                where co.obj_id = c.guid
                    )
        union
        select  cc.transaction_id, 
                cc.id, 
                cc.guid, 
                cc.name, 
                t.name as pre, 
                t.id as pre_id,
                t.lvl+1 as lvl,
                cc.revision_num
            from t
            join reclada.v_component_object co
                on t.guid = co.component_guid
            join reclada.v_component cc
                on cc.id = co.id
    ),
    h as (
        SELECT  t.transaction_id, 
                t.id, 
                t.guid, 
                t.name, 
                t.pre, 
                t.pre_id, 
                t.lvl,
                t.revision_num
            FROM t
                where name = _component_name
        union
        select  t.transaction_id, 
                t.id, 
                t.guid, 
                t.name, 
                t.pre, 
                t.pre_id, 
                t.lvl,
                null revision_num
            FROM h
            JOIN t
                on t.pre_id = h.id
    )
    insert into del_comp(tran_id, id, guid, name, rev_num)
        SELECT    transaction_id, id, guid, name, revision_num  
            FROM h;

    DELETE from reclada.object 
        WHERE transaction_id  in (select tran_id from del_comp);


    with recursive t as (
        SELECT o.transaction_id, o.obj_id
            from reclada.v_object o
                WHERE o.obj_id = (SELECT guid from del_comp where name = _component_name)
                    AND coalesce(revision_num, 1) = coalesce(
                            (SELECT rev_num from del_comp where name = _component_name), 
                            1
                        ) - 1
        union 
        select o.transaction_id, o.obj_id
            from t
            JOIN reclada.v_relationship r
                ON r.parent_guid = t.obj_id
                    AND 'data of reclada-component' = r.type
            join reclada.v_object o
                on o.obj_id = r.subject
                    and o.transaction_id >= t.transaction_id
                    and o.class_name = 'Component'
    )
    update reclada.object u
        SET status = reclada_object.get_active_status_obj_id()
        FROM t c
            WHERE u.transaction_id = c.transaction_id
                and NOT EXISTS (
                        SELECT from reclada.object o
                            WHERE o.status != reclada_object.get_archive_status_obj_id()
                                and o.guid = u.guid
                    );
    drop TABLE del_comp;
    return 'OK';
END
$$;