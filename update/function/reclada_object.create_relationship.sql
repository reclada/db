DROP FUNCTION IF EXISTS reclada_object.create_relationship;
CREATE OR REPLACE FUNCTION reclada_object.create_relationship
(
    _rel_type   text,
    _obj_GUID   uuid,
    _subj_GUID  uuid
)
RETURNS jsonb AS $$
DECLARE
    _rel_cnt    int;
BEGIN

    IF (_obj_GUID IS NULL OR _subj_GUID IS NULL) THEN
        RAISE EXCEPTION 'Object GUID IS NULL';
    END IF;

    SELECT count(*)
    FROM reclada.v_active_object
    WHERE class_name = 'Relationship'
        AND NULLIF(attrs->>'object','')::uuid   = _obj_GUID
        AND NULLIF(attrs->>'subject','')::uuid  = _subj_GUID
        AND attrs->>'type'                      = _rel_type
            INTO _rel_cnt;
    IF (_rel_cnt = 0) THEN
        RETURN  reclada_object.create(
            format('{
                "class": "Relationship",
                "attributes": {
                    "type": "%s",
                    "object": "%s",
                    "subject": "%s"
                    }
                }',
                _rel_type,
                _obj_GUID,
                _subj_GUID)::jsonb);
    ELSE
        RETURN '{}'::jsonb;
    END IF;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;