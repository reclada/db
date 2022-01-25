DROP FUNCTION IF EXISTS reclada_object.explode_jsonb;
CREATE OR REPLACE FUNCTION reclada_object.explode_jsonb(obj jsonb, addr text DEFAULT ''::text)
 RETURNS TABLE(f_path text, f_type text)
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
	_f_type	TEXT;
BEGIN
	_f_type := jsonb_typeof(obj);
	IF _f_type = 'object' THEN
		RETURN QUERY 
			SELECT b.f_path,b.f_type
			FROM jsonb_each(obj) a
			CROSS JOIN  reclada_object.explode_jsonb(value, addr || ',' || KEY) b;
	ELSE
		RETURN QUERY SELECT addr,_f_type;
	END IF;
END;
$function$
;
