
/*
 * Function api.reclada_object_delete checks valid data and uses reclada_object.delete to update object with field "isDeleted": true.
 * A jsonb with the following parameters is required.
 * Required parameters:
 *  class - the class of object and
 *  GUID - the identifier of the object or transactionID - object's transaction number. One transactionID is used for a bunch of objects.
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  attributes - the attributes of object
 *  branch - object's branch
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_delete;
CREATE OR REPLACE FUNCTION api.reclada_object_delete(
    data jsonb, 
    ver text default '1', 
    draft text default 'false'
)
RETURNS jsonb AS $$
DECLARE
    class         text;
    obj_id        uuid;
    user_info     jsonb;
    result        jsonb;

BEGIN

    obj_id := CASE ver
                when '1'
                    then data->>'GUID'
                when '2'
                    then data->>'{GUID}'
            end;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'Could not delete object with no id';
    END IF;

    if draft != 'false' then
        delete from reclada.draft 
            where guid = obj_id;
        
    else

        class := CASE ver
                        when '1'
                            then data->>'class'
                        when '2'
                            then data->>'{class}'
                    end;
        IF (class IS NULL) THEN
            RAISE EXCEPTION 'reclada object class not specified';
        END IF;

        data := data || ('{"GUID":"'|| obj_id ||'","class":"'|| class ||'"}')::jsonb;

        SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
        data := data - 'accessToken';

        IF (NOT(reclada_user.is_allowed(user_info, 'delete', class))) THEN
            RAISE EXCEPTION 'Insufficient permissions: user is not allowed to % %', 'delete', class;
        END IF;

        SELECT reclada_object.delete(data, user_info) INTO result;

    end if;

    if reclada_object.need_flat(class) 
        or draft != 'false' then 
        RETURN '{"status":"OK"}'::jsonb;
    end if;

    RETURN result;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

