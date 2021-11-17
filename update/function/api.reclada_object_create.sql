/*
 * Function api.reclada_object_create checks valid data and uses reclada_object.create to create one or bunch of objects with specified fields.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of object
 *  attributes - the attributes of object
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  GUID - the identifier of the object
 *  transactionID - object's transaction number. One transactionID is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS api.reclada_object_create;
CREATE OR REPLACE FUNCTION api.reclada_object_create(data jsonb)
RETURNS jsonb AS $$
DECLARE
    data_jsonb       jsonb;
    class            text;
    user_info        jsonb;
    attrs            jsonb;
    data_to_create   jsonb = '[]'::jsonb;
    result           jsonb;
    _need_flat       bool := false;
BEGIN

    IF (jsonb_typeof(data) != 'array') THEN
        data := '[]'::jsonb || data;
    END IF;

    FOR data_jsonb IN SELECT jsonb_array_elements(data) LOOP

        class := coalesce(data_jsonb->>'{class}', data_jsonb->>'class');
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'The reclada object class is not specified (api)';
        END IF;

        SELECT reclada_user.auth_by_token(data_jsonb->>'accessToken') INTO user_info;
        data_jsonb := data_jsonb - 'accessToken';

        -- raise notice '%',data_jsonb #> '{}';

        IF (NOT(reclada_user.is_allowed(user_info, 'create', class))) THEN
            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'create', class;
        END IF;
        
        if reclada_object.need_flat(class) then
            _need_flat := true;
            with recursive j as 
            (
                select  row_number() over() as id,
                        key,
                        value 
                    from jsonb_each(data_jsonb)
                        where key like '{%}'
            ),
            inn as 
            (
                SELECT  row_number() over(order by s.id,j.id) rn,
                        j.id,
                        s.id sid,
                        s.d,
                        ARRAY (
                            SELECT UNNEST(arr.v) 
                            LIMIT array_position(arr.v, s.d)
                        ) as k
                    FROM j
                    left join lateral
                    (
                        select id, d ,max(id) over() mid
                        from
                        (
                            SELECT  row_number() over() as id, 
                                    d
                                from regexp_split_to_table(substring(j.key,2,char_length(j.key)-2),',') d 
                        ) t
                    ) s on s.mid != s.id
                    join lateral
                    (
                        select regexp_split_to_array(substring(j.key,2,char_length(j.key)-2),',') v
                    ) arr on true
                        where d is not null
            ),
            src as
            (
                select  jsonb_set('{}'::jsonb,('{'|| i.d ||'}')::text[],'{}'::jsonb) r,
                        i.* 
                    from inn i
                        where i.rn = 1
                union
                select  jsonb_set(
                            s.r,
                            i.k,
                            '{}'::jsonb
                        ) r,
                        i.* 
                    from src s
                    join inn i
                        on s.rn + 1 = i.rn
            ),
            tmpl as (
                select r v
                    from src
                    ORDER BY rn DESC
                    limit 1
            ),
            res as
            (
                SELECT jsonb_set(
                        (select v from tmpl),
                        j.key::text[],
                        j.value
                    ) v,
                    j.*
                    FROM j
                        where j.id = 1
                union 
                select jsonb_set(
                        res.v,
                        j.key::text[],
                        j.value
                    ) v,
                    j.*
                    FROM res
                    join j
                        on res.id + 1 =j.id
            )
            SELECT v 
                FROM res
                ORDER BY ID DESC
                limit 1
                into data_jsonb;
        end if;
        data_to_create := data_to_create || data_jsonb;
    END LOOP;

    if data_to_create is null then
        RAISE EXCEPTION 'JSON invalid';
    end if;

    SELECT reclada_object.create(data_to_create, user_info) INTO result;
    if _need_flat then
        RETURN '{"status":"OK"}'::jsonb;
    end if;
    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;
