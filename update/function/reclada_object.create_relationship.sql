DROP FUNCTION IF EXISTS reclada_object.create_relationship;
CREATE OR REPLACE FUCNTION reclada_object.create_relationship
(
    _rel_type   text;
    _obj_GUID   uuid;
    _subj_GUID  uuid;
)
RETURNS jsonb AS $$
BEGIN
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
                new_data->>'GUID')::jsonb);
END;
$$ LANGUAGE 'plpgsql' VOLATILE;