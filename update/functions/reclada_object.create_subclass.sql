
/*
 * Function reclada_object.create_subclass creates subclass.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the name of class to create
 *  attrs - the attributes of objects of the class
 */

DROP FUNCTION IF EXISTS reclada_object.create_subclass(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    class           jsonb;
    attrs           jsonb;
    class_schema    jsonb;

BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class not specified';
    END IF;

    attrs := data->'attrs';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attrs';
    END IF;

	SELECT reclada_object.get_schema(class) INTO class_schema;
	
    IF (class_schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    class_schema := class_schema -> 'attrs' -> 'schema';

    PERFORM reclada_object.create(format('{
        "class": "jsonschema",
        "attrs": {
            "forClass": %s,
            "schema": {
                "type": "object",
                "properties": %s,
                "required": %s
            }
        }
    }',
    attrs -> 'newClass',
    (class_schema -> 'properties') || (attrs -> 'properties'),
    (SELECT jsonb_agg(el) FROM (SELECT DISTINCT pg_catalog.jsonb_array_elements((class_schema -> 'required') || (attrs -> 'required')) el) arr)
    )::jsonb);

END;
$$ LANGUAGE PLPGSQL VOLATILE;