/*
 * Function reclada_object.list_add adds one element or several elements to the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - id of the object
 *  field - the name of the field to add the value to
 *  value - one scalar value or array of values
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list_add(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.list_add(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          jsonb;
    obj_id         jsonb;
    obj            jsonb;
    values_to_add  jsonb;
    field_value    jsonb;
    json_path      text[];
    new_obj        jsonb;
    res            jsonb;
 
BEGIN

    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

	-- validate obj_id as uuid
	PERFORM (data->>'id')::uuid;

    obj_id := data->'id';
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'There is no id';
    END IF;

	/*
    SELECT reclada_object.list(format(
        '{"class": %s, "attrs": {}, "id": "%s"}',
        class,
        obj_id
        )::jsonb) -> 0 INTO obj;
	*/
	SELECT 	v.data
		FROM reclada.v_object v
			WHERE v.id = obj_id
		INTO obj;
	
    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    values_to_add := data->'value';
    IF (values_to_add IS NULL OR values_to_add = 'null'::jsonb) THEN
        RAISE EXCEPTION 'The value should not be null';
    END IF;

    IF (jsonb_typeof(values_to_add) != 'array') THEN
        values_to_add := format('[%s]', values_to_add)::jsonb;
    END IF;

    field_value := data->'field';
    IF (field_value IS NULL) THEN
        RAISE EXCEPTION 'There is no field';
    END IF;
    json_path := format('{attrs, %s}', field_value);
    field_value := obj#>json_path;

    IF ((field_value = 'null'::jsonb) OR (field_value IS NULL)) THEN
        SELECT jsonb_set(obj, json_path, values_to_add)
        INTO new_obj;
    ELSE
        SELECT jsonb_set(obj, json_path, field_value || values_to_add)
        INTO new_obj;
    END IF;

    SELECT reclada_object.update(new_obj) INTO res;
    RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

