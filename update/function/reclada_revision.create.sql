DROP FUNCTION IF EXISTS reclada_revision.create;
CREATE OR REPLACE FUNCTION reclada_revision.create
(
    userid varchar, 
    branch uuid, 
    obj uuid
)
RETURNS uuid AS $$
    INSERT INTO reclada.object
        (
            class,
            attributes
        )
               
        VALUES
        (
            (reclada_object.get_schema('revision')->>'GUID')::uuid,-- class,
            format                    -- attributes
            (                         
                '{
                    "num": %s,
                    "user": "%s",
                    "dateTime": "%s",
                    "branch": "%s"
                }',
                (
                    select count(*) + 1
                        from reclada.object o
                            where o.GUID = obj
                ),
                userid,
                now(),
                branch
            )::jsonb
        ) RETURNING (GUID)::uuid;
    --nextval('reclada.reclada_revisions'),
$$ LANGUAGE SQL VOLATILE;
