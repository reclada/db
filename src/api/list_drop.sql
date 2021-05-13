/*
 * Function api.list_drop drops one element or several elements from the list.
 * Input required parameter is jsonb with:
 * class - the class of the object
 * id - id of the object
 * field - the name of the field to drop the value from
 * value - one scalar value or array of values
 * access_token - jwt token to authorize
*/

DROP FUNCTION IF EXISTS api.list_drop(jsonb);
CREATE OR REPLACE FUNCTION api.list_drop(data jsonb)
RETURNS void AS $$
DECLARE  
    class           jsonb;
    obj_id 		    uuid;
    values_to_drop  jsonb;
    new_value 	    jsonb;
    json_path       text[];
    obj		 	    jsonb;
    new_obj		    jsonb;
    field_value     jsonb;
    access_token    text;

BEGIN
	class := data->'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
	END IF;
	
	obj_id := (data->>'id')::uuid;
	IF (obj_id IS NULL) THEN
		RAISE EXCEPTION 'The is no id';
	END IF;
	
	access_token := data->>'access_token';
	SELECT api.reclada_object_list(format(
		'{"class": %s, "attrs": {}, "id": "%s", "access_token": "%s"}',
		class,
		obj_id,
		access_token
		)::jsonb) -> 0 INTO obj;
    	
	IF (obj IS NULL) THEN
		RAISE EXCEPTION 'The is no object with such id';
	END IF;
    
	values_to_drop := data->'value';
	IF (values_to_drop IS NULL OR values_to_drop = 'null'::jsonb) THEN
		RAISE EXCEPTION 'The value should not be null';
	END IF;
    
	IF (jsonb_typeof(values_to_drop) != 'array') THEN
		values_to_drop := format('[%s]', values_to_drop)::jsonb;
	END IF;
    
	field_value :=  data->'field';
	IF (field_value IS NULL OR field_value = 'null'::jsonb) THEN
		RAISE EXCEPTION 'There is no field';
	END IF;
	json_path := format('{attrs, %s}', field_value);
	field_value := obj#>json_path;
	IF (field_value IS NULL) THEN
		RAISE EXCEPTION 'The object does not have this field';
	END IF;
    
	SELECT jsonb_agg(elems)
	FROM
		jsonb_array_elements(field_value) elems
	WHERE 
		elems NOT IN (
			SELECT jsonb_array_elements(values_to_drop))
	INTO new_value;
		
	SELECT jsonb_set(obj, json_path, coalesce(new_value, '[]'::jsonb)) || format('{"access_token": "%s"}', access_token)::jsonb
	INTO new_obj;
	
	PERFORM api.reclada_object_update(new_obj);
	
END;
$$ LANGUAGE PLPGSQL VOLATILE;

