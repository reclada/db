/*
 * Auxiliary function cast_jsonb_to_postgres generates a string to get the jsonb field with a cast to postgres primitive types.
 * Required parameters:
 *  key_path - the path to jsonb object field
 *  type - a primitive json type
 * Optional parameters:
 *  type_of_array - the type to which it needed to cast elements of array. It is used just for type = array. By default, type_of_array = text.
 * Examples:
 * 1. Input: key_path = data->'revision', type = number
 *    Output: (data->'revision')::numeric
 * 2. Input: key_path = data->'attributes'->'tags', type = array, type_of_array = string
 *    Output: (ARRAY(SELECT jsonb_array_elements_text(data->'attributes'->'tags')::text)
 * Only valid input is expected.
*/

DROP FUNCTION IF EXISTS reclada_object.cast_jsonb_to_postgres;
CREATE OR REPLACE FUNCTION reclada_object.cast_jsonb_to_postgres(key_path text, type text, type_of_array text default 'text')
RETURNS text AS $$
SELECT
        CASE
            WHEN type = 'string' THEN
                format(E'(%s#>>\'{}\')::text', key_path)
            WHEN type = 'number' THEN
                format(E'(%s)::numeric', key_path)
            WHEN type = 'boolean' THEN
                format(E'(%s)::boolean', key_path)
            WHEN type = 'array' THEN
                format(
                    E'ARRAY(SELECT jsonb_array_elements_text(%s)::%s)',
                    key_path,
                     CASE
                        WHEN type_of_array = 'string' THEN 'text'
                        WHEN type_of_array = 'number' THEN 'numeric'
                        WHEN type_of_array = 'boolean' THEN 'boolean'
                     END
                    )
        END
$$ LANGUAGE SQL IMMUTABLE;

