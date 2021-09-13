
drop VIEW if EXISTS reclada.v_class;
CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT
            obj.id,
            obj.GUID as obj_id,
            obj.class,
            obj.attributes->>'forClass' as for_class,
            (obj.attributes->>'version')::bigint as version,
            r.num as revision_num,
            NULLIF(obj.attributes ->> 'revision','')::uuid as revision,
            obj.status,
            obj.created_time,
            obj.created_by,
            obj.attributes as attrs,
            (
                SELECT json_agg(tmp)->0
                    FROM
                    (
                        SELECT  obj.GUID as "GUID",
                                obj.class as class,
                                obj.status as status,
                                NULLIF(obj.attributes ->> 'revision','')::uuid as revision,
                                obj.attributes as attributes
                    ) AS tmp
            )::jsonb AS data
        FROM reclada.object obj
        LEFT JOIN
        (
            SELECT (r.attributes->>'num')::bigint num,
                   r.GUID
                FROM reclada.object r
                    WHERE class IN (
                        SELECT GUID
                        FROM reclada.object
                        WHERE attributes->>'forClass' = 'revision'
                        AND attributes->>'version' = (SELECT max(attributes->>'version') FROM reclada.object WHERE attributes->>'forClass' = 'revision')
                        )
        ) r
            ON r.GUID = NULLIF(obj.attributes ->> 'revision','')::uuid
        WHERE class = reclada_object.get_jsonschema_GUID();


--select * from reclada.v_class_
--select * from reclada.v_class
