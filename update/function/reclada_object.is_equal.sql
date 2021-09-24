DROP FUNCTION IF EXISTS reclada_object.is_equal;
CREATE OR REPLACE FUNCTION reclada_object.is_equal(lobj jsonb, robj jsonb)
	RETURNS bool
	LANGUAGE plpgsql
	IMMUTABLE
AS $function$
	DECLARE
		cnt 	int;
		ltype	text;
		rtype	text;
	BEGIN
		ltype := jsonb_typeof(lobj);
		rtype := jsonb_typeof(robj);
		IF ltype != rtype THEN
			RETURN False;
		END IF;
		CASE ltype 
		WHEN 'object' THEN
			SELECT count(*) INTO cnt FROM (                     -- Using joining operators compatible with merge or hash join is obligatory
				SELECT 1                                        --    with FULL OUTER JOIN. is_equal is compatible only with NESTED LOOPS
				FROM (SELECT jsonb_each(lobj) AS rec) a         --    so I use LEFT JOIN UNION ALL RIGHT JOIN insted of FULL OUTER JOIN.
				LEFT JOIN
					(SELECT jsonb_each(robj) AS rec) b
				ON (a.rec).key = (b.rec).key AND reclada_object.is_equal((a.rec).value, (b.rec).value)  
				WHERE b.rec IS NULL
            UNION ALL 
				SELECT 1
				FROM (SELECT jsonb_each(robj) AS rec) a
				LEFT JOIN
					(SELECT jsonb_each(lobj) AS rec) b
				ON (a.rec).key = (b.rec).key AND reclada_object.is_equal((a.rec).value, (b.rec).value)  
				WHERE b.rec IS NULL
			) a;
			RETURN cnt=0;
		WHEN 'array' THEN
			SELECT count(*) INTO cnt FROM (
				SELECT 1
				FROM (SELECT jsonb_array_elements (lobj) AS rec) a
				LEFT JOIN
					(SELECT jsonb_array_elements (robj) AS rec) b
				ON reclada_object.is_equal((a.rec), (b.rec))  
				WHERE b.rec IS NULL
				UNION ALL
				SELECT 1
				FROM (SELECT jsonb_array_elements (robj) AS rec) a
				LEFT JOIN
					(SELECT jsonb_array_elements (lobj) AS rec) b
				ON reclada_object.is_equal((a.rec), (b.rec))  
				WHERE b.rec IS NULL
			) a;
			RETURN cnt=0;
		WHEN 'string' THEN
			RETURN text(lobj) = text(robj);
		WHEN 'number' THEN
			RETURN lobj::numeric = robj::numeric;
		WHEN 'boolean' THEN
			RETURN lobj::boolean = robj::boolean;
		WHEN 'null' THEN
			RETURN True;                                    -- It should be Null
		ELSE
			RETURN null;
		END CASE;
	END;
$function$
;