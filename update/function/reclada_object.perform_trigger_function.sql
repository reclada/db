DROP FUNCTION IF EXISTS reclada_object.perform_trigger_function;
CREATE OR REPLACE FUNCTION reclada_object.perform_trigger_function
(
    _list_id         bigint[],
    _trigger_type       text
)
RETURNS void AS $$
DECLARE
    _query          text ;           
BEGIN
    SELECT string_agg(sbq.subquery, '')
	    FROM ( 
            SELECT  'SELECT reclada.' 
                    || vtf.function_name 
                    || '(' 
                    || idcl.id
                    || ');'
                    || chr(10) AS subquery
                FROM reclada.v_trigger vt
                    JOIN reclada.v_db_trigger_function vtf
                        ON vt.function_guid = vtf.function_guid
                    CROSS JOIN (SELECT vo.id, vo.class_name 
                            FROM reclada.v_object vo
                                WHERE vo.id IN (SELECT unnest(_list_id))
                        ) idcl
                        WHERE vt.trigger_type = _trigger_type
                            AND idcl.class_name IN (SELECT jsonb_array_elements_text(vt.for_classes))
            ) sbq
        INTO _query;

    IF _query IS NOT NULL THEN
        raise notice '(%)', _query;
        EXECUTE _query;
    END IF;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;