/*
 * Function reclada_object.get_schema returns the last version of jsonschema of the object.
 * Required parameters:
 *  _class - the name of class for jsonschema
 * NOTICE: there is one latest version in v_class as the versions of two jsonschema cannot be the same
 */

DROP FUNCTION IF EXISTS reclada_object.get_schema;
CREATE OR REPLACE FUNCTION reclada_object.get_schema(_class text)
RETURNS jsonb AS $$
    SELECT data
    FROM reclada.v_class_lite v
    JOIN reclada.v_active_object vao ON v.id=vao.id
    WHERE v.for_class = _class
    ORDER BY v.version DESC
    LIMIT 1
$$ LANGUAGE SQL STABLE;