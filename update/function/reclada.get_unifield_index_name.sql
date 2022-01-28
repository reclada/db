DROP FUNCTION IF EXISTS reclada.get_unifield_index_name;
CREATE OR REPLACE FUNCTION reclada.get_unifield_index_name
(
    fields text[]
)
RETURNS text  
LANGUAGE sql
 STABLE
AS $function$
	SELECT lower(array_to_string(fields,'_'))||'_index_';
$function$
;