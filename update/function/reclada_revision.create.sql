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
            revision,
            class,
            attrs
        )
               
        VALUES
        (

            null                     ,-- revision,
            'revision'               ,-- class,
            format                    -- attrs
            (                         
                '{
                    "num": %s,
                    "user": "%s",
                    "dateTime": "%s",
                    "branch": "%s"
                }',
                (
                    select count(distinct o.revision)+1 
                        from reclada.object o
                            where o.obj_id = obj
                ),
                userid,
                now(),
                branch
            )::jsonb
        ) RETURNING (obj_id)::uuid;
    --nextval('reclada.reclada_revisions'),
$$ LANGUAGE SQL VOLATILE;
