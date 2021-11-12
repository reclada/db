DROP FUNCTION IF EXISTS reclada_object.update_json_by_guid;
CREATE OR REPLACE FUNCTION reclada_object.update_jsonby_guid(lobj uuid, robj jsonb)
    RETURNS jsonb
    LANGUAGE sql
    VOLATILE
AS $function$
    SELECT reclada_object.update_json(data, robj)
    FROM reclada.v_active_object
    WHERE obj_id = lobj;
$function$
;