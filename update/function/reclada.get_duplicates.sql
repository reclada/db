/*
 * Function reclada.get_duplicates returns GUID, duplicate behavior, duplicate field.
 * Required parameters:
 *  _attrs      - attributes of object
 *  _class_uuid - class of object
 */

DROP FUNCTION IF EXISTS reclada.get_duplicates;
CREATE OR REPLACE FUNCTION reclada.get_duplicates(_attrs jsonb, _class_uuid uuid, exclude_uuid  uuid = NULL)
RETURNS TABLE (
    obj_guid        uuid,
    dup_behavior    reclada.dp_bhvr,
    is_cascade      boolean,
    dup_field       text) AS $$
DECLARE
    q text;
BEGIN
    SELECT val
    FROM reclada.v_get_duplicates_query
    LIMIT 1
        INTO q;
    q := REPLACE(q, '@#@#@attrs@#@#@',          _attrs::text);
    q := REPLACE(q, '@#@#@class_uuid@#@#@',     _class_uuid::text);
    IF exclude_uuid IS NULL THEN
        q := REPLACE(q, '@#@#@exclude_uuid@#@#@',   ''::text);    
    ELSE
        q := REPLACE(q, '@#@#@exclude_uuid@#@#@',   ' || ''AND obj_id != '''''::text || exclude_uuid::text || '''''''');
    END IF;

    EXECUTE q
        INTO q;
    
    RETURN QUERY EXECUTE q;
END;            
$$ LANGUAGE PLPGSQL STABLE;