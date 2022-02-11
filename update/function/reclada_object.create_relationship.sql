DROP FUNCTION IF EXISTS reclada_object.create_relationship;
CREATE OR REPLACE FUNCTION reclada_object.create_relationship
(
    _rel_type   text,
    _obj_GUID   uuid,
    _subj_GUID  uuid,
    _extra_attrs    jsonb DEFAULT '{}'::jsonb,
    _parent_guid    uuid  default null
)
RETURNS jsonb AS $$
DECLARE
    _rel_cnt    int;
    _obj        jsonb;
BEGIN

    IF _obj_GUID IS NULL OR _subj_GUID IS NULL THEN
        RAISE EXCEPTION 'Object GUID or Subject GUID IS NULL';
    END IF;

    SELECT count(*)
    FROM reclada.v_active_object
    WHERE class_name = 'Relationship'
        AND (attrs->>'object')::uuid   = _obj_GUID
        AND (attrs->>'subject')::uuid  = _subj_GUID
        AND attrs->>'type'                      = _rel_type
            INTO _rel_cnt;
    IF (_rel_cnt = 0) THEN
        _obj := format('{
            "class": "Relationship",
            "attributes": {
                    "type": "%s",
                    "object": "%s",
                    "subject": "%s"
                }
            }',
            _rel_type,
            _obj_GUID,
            _subj_GUID)::jsonb;
        _obj := jsonb_set (_obj, '{attributes}', _obj->'attributes' || _extra_attrs);   
        if _parent_guid is not null then
            _obj := jsonb_set (_obj, '{parentGUID}', to_jsonb(_parent_guid) );   
        end if;

        RETURN  reclada_object.create( _obj);
    ELSE
        RETURN '{}'::jsonb;
    END IF;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;