/*
 * Function reclada_object.create creates one or bunch of objects with specified fields.
 * A jsonb with user_info and a jsonb or an array of jsonb objects are required.
 * A jsonb object with the following parameters is required to create one object.
 * An array of jsonb objects with the following parameters is required to create a bunch of objects.
 * Required parameters:
 *  class - the class of objects
 *  attributes - the attributes of objects
 * Optional parameters:
 *  GUID - the identifier of the object
 *  transactionID - object's transaction number. One transactionID is used to create a bunch of objects.
 *  branch - object's branch
 */

DROP FUNCTION IF EXISTS reclada_object.refresh_mv;
CREATE OR REPLACE FUNCTION reclada_object.refresh_mv
(
    class_name text
)
RETURNS void AS $$
BEGIN
    CASE class_name
        WHEN 'ObjectStatus' THEN
            REFRESH MATERIALIZED VIEW reclada.v_object_status;
        WHEN 'User' THEN
            REFRESH MATERIALIZED VIEW reclada.v_user;
        WHEN 'jsonschema' THEN
            REFRESH MATERIALIZED VIEW reclada.v_class_lite;
        ELSE
            NULL;
    END CASE;
END;
$$ LANGUAGE PLPGSQL VOLATILE;