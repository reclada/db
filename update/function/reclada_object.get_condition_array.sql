/*
 * Auxiliary function get_condition_array generates a query string to get the jsonb field which contains array with a cast to postgres primitive types.
 * Required parameters:
 *  data - the jsonb field which contains array
 *  key_path - the path to jsonb object field
 * Examples:
 * 1. Input: data = {"operator": "inList", "object": [60, 64, 65]}::jsonb,
             key_path = data->'revision'
 *    Output: ((data->'revision')::numeric = ANY(ARRAY[60, 64, 65]))
 * 2. Input: data = {"object": ["value1", "value2", "value3"]}::jsonb,
             key_path = data->'attrs'->'tags'
 *    Output: ((ARRAY(SELECT jsonb_array_elements_text(data->'attrs'->'tags')::text) = ARRAY['value1', 'value2', 'value3'])
 * Only valid input is expected.
*/

DROP FUNCTION IF EXISTS reclada_object.get_condition_array(jsonb, text);
CREATE OR REPLACE FUNCTION reclada_object.get_condition_array(data jsonb, key_path text)
RETURNS text AS $$
    SELECT
    CONCAT(
        key_path,
        ' ', data->>'operator', ' ',
        format(E'\'%s\'::jsonb', data->'object'#>>'{}'))
$$ LANGUAGE SQL IMMUTABLE;
