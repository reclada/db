DROP FUNCTION IF EXISTS reclada_object.remove_parent_guid;
CREATE OR REPLACE FUNCTION reclada_object.remove_parent_guid(_data jsonb, parent_field text)
    RETURNS jsonb
    LANGUAGE plpgsql
    STABLE
AS $function$
    BEGIN
        IF (parent_field IS NOT NULL) THEN
            _data := _data #- format('{attributes,%s}',parent_field)::text[];
        END IF;
        _data := _data - 'parent_guid';
        _data := _data - 'GUID';
        RETURN _data;
    END;
$function$
;