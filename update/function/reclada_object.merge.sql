DROP FUNCTION IF EXISTS reclada_object.merge;
CREATE OR REPLACE FUNCTION reclada_object.merge(lobj jsonb, robj jsonb, schema jsonb default null)
    RETURNS jsonb
    LANGUAGE plpgsql
    STABLE
AS $function$
    DECLARE
        res     jsonb;
        ltype    text;
        rtype    text;
    BEGIN
        ltype := jsonb_typeof(lobj);
        rtype := jsonb_typeof(robj);
        IF (lobj IS NULL AND robj IS NOT NULL) THEN
            RETURN robj;
        END IF;
        IF (lobj IS NOT NULL AND robj IS NULL) THEN
            RETURN lobj;
        END IF;
        IF (ltype = 'null') THEN
            RETURN robj;
        END IF;
        IF (ltype != rtype) THEN
            RETURN lobj || robj;
        END IF;
        IF reclada_object.is_equal(lobj,robj) THEN
            RETURN lobj;
        END IF;
        CASE ltype 
        WHEN 'object' THEN
            SELECT jsonb_object_agg(key,val)
            FROM (
                SELECT key, reclada_object.merge(lval,rval) as val
                    FROM (                     -- Using joining operators compatible with merge or hash join is obligatory
                    SELECT (a.rec).key as key,
                        (a.rec).value AS lval,
                        (b.rec).value AS rval                                        --    with FULL OUTER JOIN. merge is compatible only with NESTED LOOPS
                    FROM (SELECT jsonb_each(lobj) AS rec) a         --    so I use LEFT JOIN UNION ALL RIGHT JOIN insted of FULL OUTER JOIN.
                    LEFT JOIN
                        (SELECT jsonb_each(robj) AS rec) b
                    ON (a.rec).key = (b.rec).key
                UNION
                    SELECT (a.rec).key as key,
                        (b.rec).value AS lval,
                        (a.rec).value AS rval
                    FROM (SELECT jsonb_each(robj) AS rec) a
                    LEFT JOIN
                        (SELECT jsonb_each(lobj) AS rec) b
                    ON (a.rec).key = (b.rec).key
                ) a
            ) b
                INTO res;
            IF schema IS NOT NULL AND NOT validate_json_schema(schema, res) THEN
                RAISE EXCEPTION 'Objects aren''t mergeable. Solve duplicate conflicate manually.';
            END IF;
            RETURN res;
        WHEN 'array' THEN
            SELECT to_jsonb(array_agg(rec)) FROM (
                SELECT COALESCE(a.rec, b.rec) as rec
                FROM (SELECT jsonb_array_elements (lobj) AS rec) a
                LEFT JOIN
                    (SELECT jsonb_array_elements (robj) AS rec) b
                ON reclada_object.is_equal((a.rec), (b.rec))
                UNION
                SELECT COALESCE(a.rec, b.rec) as rec
                FROM (SELECT jsonb_array_elements (robj) AS rec) a
                LEFT JOIN
                    (SELECT jsonb_array_elements (lobj) AS rec) b
                ON reclada_object.is_equal((a.rec), (b.rec))
            ) a
                INTO res;
            RETURN res;
        WHEN 'string' THEN
            RETURN lobj || robj;
        WHEN 'number' THEN
            RETURN lobj || robj;
        WHEN 'boolean' THEN
            RETURN lobj || robj;
        WHEN 'null' THEN
            RETURN '{}'::jsonb;                                    -- It should be Null
        ELSE
            RETURN null;
        END CASE;
    END;
$function$
;