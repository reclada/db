DROP FUNCTION IF EXISTS reclada_object.update_json;
CREATE OR REPLACE FUNCTION reclada_object.update_json(lobj jsonb, robj jsonb)
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
        IF (robj IS NULL) THEN
            RETURN lobj;
        END IF;
        IF (lobj IS NULL) THEN
            RETURN robj;
        END IF;
        IF reclada_object.is_equal(lobj,robj) THEN
            RETURN lobj;
        END IF;
        IF (ltype = 'array' and rtype != 'array') THEN
            RETURN lobj || robj;
        END IF;
        IF (ltype != rtype) THEN
            RETURN robj;
        END IF;
        CASE ltype 
        WHEN 'object' THEN
            SELECT jsonb_object_agg(key,val)
            FROM (
                SELECT key, reclada_object.update_json(lval,rval) AS val
                FROM (                     -- Using joining operators compatible with update_json or hash join is obligatory
                    SELECT (a.rec).key as key,
                        (a.rec).value AS lval,
                        (b.rec).value AS rval                                        --    with FULL OUTER JOIN. update_json is compatible only with NESTED LOOPS
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
            RETURN res;
        WHEN 'array' THEN
            RETURN robj;
        WHEN 'string' THEN
            RETURN robj;
        WHEN 'number' THEN
            RETURN robj;
        WHEN 'boolean' THEN
            RETURN robj;
        WHEN 'null' THEN
            RETURN '{}'::jsonb;                                    -- It should be Null
        ELSE
            RETURN null;
        END CASE;
    END;
$function$
;