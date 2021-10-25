/*
 * Function reclada_object.create_subclass creates subclass.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the name of parent class
 *  attributes - the attributes of objects of the class. The field contains:
 *      forClass - the name of class to create
 *      schema - the schema for the class
 */

DROP FUNCTION IF EXISTS reclada_object.create_subclass;
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    class           text;
    new_class       text;
    attrs           jsonb;
    class_schema    jsonb;
    version_         integer;
    class_guid    uuid;
BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    attrs := data->'attributes';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    new_class = attrs->>'newClass';

    SELECT reclada_object.get_schema(class) INTO class_schema;

    IF (class_schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    SELECT max(version) + 1
    FROM reclada.v_class_lite v
    WHERE v.for_class = new_class
    INTO version_;

    version_ := coalesce(version_,1);
    class_schema := class_schema->'attributes'->'schema';

    SELECT obj_id
    FROM reclada.v_class
    WHERE for_class = class
    ORDER BY version DESC
    LIMIT 1
    INTO class_guid;

    PERFORM reclada_object.create(format('{
        "class": "jsonschema",
        "attributes": {
            "forClass": "%s",
            "version": "%s",
            "schema": {
                "type": "object",
                "properties": %s,
                "required": %s
            }
        },
        "parent_guid" : "%s"
    }',
    new_class,
    version_,
    (class_schema->'properties') || (attrs->'properties'),
    (SELECT jsonb_agg(el) FROM (
        SELECT DISTINCT pg_catalog.jsonb_array_elements(
            (class_schema -> 'required') || (attrs -> 'required')
        ) el) arr),
    class_guid
    )::jsonb);

END;
$$ LANGUAGE PLPGSQL VOLATILE;

