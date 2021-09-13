/*
 * Function reclada_object.get_schema returns the last version of jsonschema of the object.
 * Required parameters:
 *  class - the name of class for jsonschema
 * NOTICE: there is one latest version in v_class as the versions of two jsonschema cannot be the same
 */

DROP FUNCTION IF EXISTS reclada_object.get_schema;
CREATE OR REPLACE FUNCTION reclada_object.get_schema(class_text text)
RETURNS jsonb AS $$
    SELECT data
    FROM reclada.v_class v
    WHERE v.for_class = class_text
    ORDER BY v.version DESC
    LIMIT 1
$$ LANGUAGE SQL STABLE;