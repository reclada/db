DROP FUNCTION IF EXISTS reclada_revision.create(uuid, uuid);
CREATE OR REPLACE FUNCTION reclada_revision.create(userid uuid, branch uuid)
RETURNS integer AS $$
    INSERT INTO reclada.object VALUES(format(
        '{
            "id": %s,
            "class": "revision",
            "attrs": {
                "user": "%s",
                "dateTime": "%s",
                "branch": "%s"
            }
        }',
        nextval('reclada_revisions'),
        userid,
        now(),
        branch
    )::jsonb) RETURNING (data->'id')::integer;
$$ LANGUAGE SQL VOLATILE;
