

DROP FUNCTION IF EXISTS reclada.update_unique_object;
CREATE OR REPLACE FUNCTION reclada.update_unique_object
(
    guid_list uuid[]
)
RETURNS bool AS $$
DECLARE
    _query_conditions   text;
    _exec_text          text;
    _pre_query          text;
BEGIN
    if coalesce(array_length(guid_list,1),0) != 0 then

        _query_conditions := replace(
                replace(
                    replace((guid_list)::text,
                        '{', 'obj.obj_id in ('''),
                    '}', '''::uuid)'),
                ',','''::uuid,''');
        _pre_query := (select val from reclada.v_ui_active_object);
        _pre_query := REPLACE(_pre_query,'#@#@#where#@#@#', _query_conditions);

        _exec_text := _pre_query ||',
            dd as (
                select obj.id, unnest(obj.display_key) v
                    FROM res AS obj
            ),
            insrt_data as 
            (
                select dd.id, splt.v[1]   as path, splt.v[2] as json_type 
                    from dd
                    join lateral 
                    (
                        select regexp_split_to_array(dd.v,''#@#@#separator#@#@#'') v
                    ) splt on true 
            ),
            insrt as 
            (
                insert into reclada.field(path, json_type)
                    select distinct idt.path, idt.json_type
                        from insrt_data idt
                    ON CONFLICT(path, json_type)
                    DO NOTHING
                    returning id, path, json_type
            ),
            fields as 
            (
                select rf.id, rf.path, rf.json_type
                    from reclada.field rf
                    join insrt_data idt
                        on idt.path = rf.path
                            and idt.json_type = rf.json_type
                union -- like distinct
                select rf.id, rf.path, rf.json_type 
                    from insrt rf
                        
            ),
            uo_data as(
                select  idt.id as id_reclada_object,
                        array_agg(
                            rf.id order by rf.id
                        ) as id_field
                    from insrt_data idt
                    join fields rf
                        on idt.path = rf.path
                            and idt.json_type = rf.json_type
                        group by idt.id
            ),
            instr_uo as (
                insert into reclada.unique_object(id_field)
                    select distinct uo.id_field
                        from uo_data uo
                    ON CONFLICT(id_field)
                        DO NOTHING
                    returning id, id_field
            ),
            uo as 
            (
                select uo.id as id_unique_object, uo.id_field
                    from reclada.unique_object uo
                    join uo_data idt
                        on idt.id_field = uo.id_field
                union -- like distinct
                select uo.id, uo.id_field
                    from instr_uo uo
            )
            insert into reclada.unique_object_reclada_object(id_unique_object,id_reclada_object)
                SELECT uo.id_unique_object, idt.id_reclada_object
                    FROM uo
                    join uo_data idt
                        on idt.id_field = uo.id_field
                ON CONFLICT(id_unique_object,id_reclada_object)
                    DO NOTHING';

        EXECUTE _exec_text;

        RETURN true;
    else
        RETURN false;
    end if;
END;
$$ LANGUAGE PLPGSQL VOLATILE;