/*
 * Auxiliary function get_query_condition generates a query string.
 * Required parameters:
 *  data - the jsonb field which contains query information
 *  key_path - the path to jsonb object field
 * Examples:
 * 1. Input: data = [{"operator": ">=", "object": 100}, {"operator": "<", "object": 124}]::jsonb,
 *            key_path = data->'revision'
 *    Output: (((data->'revision')::numeric >= 100) AND ((data->'revision')::numeric < 124))
 * 2. Input: data = {"operator": "LIKE", "object": "%test%"}::jsonb,
 *            key_path = data->'name'
 *    Output: ((data->'attrs'->'name'#>>'{}')::text LIKE '%test%')
*/

DROP FUNCTION IF EXISTS reclada_object.get_query_condition(jsonb, text);
CREATE OR REPLACE FUNCTION reclada_object.get_query_condition(data jsonb, key_path text)
RETURNS text AS $$
DECLARE
    key          text;
    operator     text;
    value        text;
    res          text;

BEGIN
    IF (data IS NULL OR data = 'null'::jsonb) THEN
        RAISE EXCEPTION 'There is no condition';
    END IF;

    IF (jsonb_typeof(data) = 'object') THEN

        IF (data->'object' IS NULL OR data->'object' = ('null'::jsonb)) THEN
            RAISE EXCEPTION 'There is no object field';
        END IF;

        IF (jsonb_typeof(data->'object') = 'object') THEN
            RAISE EXCEPTION 'The input_jsonb->''object'' can not contain jsonb object';
        END IF;

        IF (jsonb_typeof(data->'operator') != 'string' AND data->'operator' IS NOT NULL) THEN
            RAISE EXCEPTION 'The input_jsonb->''operator'' must contain string';
        END IF;

        IF (jsonb_typeof(data->'object') = 'array') THEN
            res := reclada_object.get_condition_array(data, key_path);
        ELSE
            key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data->'object'));
            operator :=  data->>'operator';
            value := reclada_object.jsonb_to_text(data->'object');
            res := key || ' ' || operator || ' ' || value;
        END IF;
    ELSE
        key := reclada_object.cast_jsonb_to_postgres(key_path, jsonb_typeof(data));
        operator := '=';
        value := reclada_object.jsonb_to_text(data);
        res := key || ' ' || operator || ' ' || value;
    END IF;
    RETURN res;

END;
$$ LANGUAGE PLPGSQL STABLE;
