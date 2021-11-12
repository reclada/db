DROP FUNCTION IF EXISTS reclada_object.remove_parent_guid;
CREATE OR REPLACE FUNCTION reclada_object.remove_parent_guid(_data jsomb, parent_field text)
    RETURNS jsonb
    LANGUAGE plpgsql
    STABLE
AS $function$
    BEGIN
        _data := _data #- format('{attributes,%s',parent_field)::text[];
        _data := _data - 'parent_guid';
        _data := _data - 'GUID';
    END;
$function$
;