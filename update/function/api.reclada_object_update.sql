
/*
 * Function api.reclada_object_update checks valid data and uses reclada_object.update to update object with new revision.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object
 *  GUID - the identifier of the object
 *  attributes - the attributes of object
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_update;
CREATE OR REPLACE FUNCTION api.reclada_object_update(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class         text;
    objid         uuid;
    attrs         jsonb;
    user_info     jsonb;
    result        jsonb;
    _need_flat    bool := false;

BEGIN

    class := coalesce(data ->> '{class}', data ->> 'class');
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'reclada object class not specified';
    END IF;

    objid := coalesce(data ->> '{GUID}', data ->> 'GUID');
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'Could not update object with no GUID';
    END IF;
    
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'update', class))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'update', class;
    END IF;

    if reclada_object.need_flat(class) then
        _need_flat := true;
        with recursive j as 
        (
            select  row_number() over() as id,
                    key,
                    value 
                from jsonb_each(data)
                    where key like '{%}'
        ),
        t as
        (
            select  j.id    , 
                    j.key   , 
                    j.value , 
                    o.data
                from reclada.v_object o
                join j
                    on true
                    where o.obj_id = 
                        (
                            select (j.value#>>'{}')::uuid 
                                from j where j.key = '{GUID}'
                        )
        ),
        r as 
        (
            select id,key,value,jsonb_set(t.data,t.key::text[],t.value) as u, t.data
                from t
                    where id = 1
            union
            select t.id,t.key,t.value,jsonb_set(r.u   ,t.key::text[],t.value) as u, t.data
                from r
                JOIN t
                    on t.id-1 = r.id
        )
        select r.u
            from r
                where id = (select max(j.id) from j)
            INTO data;
    end if;
    raise notice '%', data#>>'{}';
    SELECT reclada_object.update(data, user_info) INTO result;

    if _need_flat then
        RETURN '{"status":"OK"}'::jsonb;
    end if;
    return result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

