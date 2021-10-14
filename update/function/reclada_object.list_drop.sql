/*
 * Function reclada_object.list_drop drops one element or several elements from the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  GUID - the identifier of the object
 *  field - the name of the field to drop the value from
 *  value - one scalar value or array of values
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list_drop;
CREATE OR REPLACE FUNCTION reclada_object.list_drop(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class           text;
    objid           uuid;
    obj             jsonb;
    values_to_drop  jsonb;
    field           text;
    field_value     jsonb;
    json_path       text[];
    new_value       jsonb;
    new_obj         jsonb;
    res             jsonb;

BEGIN

	class := data->>'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;

	objid := (data->>'GUID')::uuid;
	IF (objid IS NULL) THEN
		RAISE EXCEPTION 'There is no GUID';
	END IF;

    SELECT v.data
    FROM reclada.v_active_object v
    WHERE v.obj_id = objid
    INTO obj;

	IF (obj IS NULL) THEN
		RAISE EXCEPTION 'There is no object with such id';
	END IF;

	values_to_drop := data->'value';
	IF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN
		RAISE EXCEPTION 'The value should not be null';
	END IF;

	IF (jsonb_typeof(values_to_drop) != 'array') THEN
		values_to_drop := format('[%s]', values_to_drop)::jsonb;
	END IF;

	field := data->>'field';
	IF (field IS NULL) THEN
		RAISE EXCEPTION 'There is no field';
	END IF;
	json_path := format('{attributes, %s}', field);
	field_value := obj#>json_path;
	IF (field_value IS NULL OR field_value = 'null'::jsonb) THEN
		RAISE EXCEPTION 'The object does not have this field';
	END IF;

	SELECT jsonb_agg(elems)
	FROM
		jsonb_array_elements(field_value) elems
	WHERE
		elems NOT IN (
			SELECT jsonb_array_elements(values_to_drop))
	INTO new_value;

	SELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb))
	INTO new_obj;

	SELECT reclada_object.update(new_obj) INTO res;
	RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;
