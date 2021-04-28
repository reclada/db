DROP FUNCTION IF EXISTS api.list_add(jsonb);

CREATE OR REPLACE FUNCTION api.list_add(data jsonb)
RETURNS void AS $$
DECLARE  
	class          jsonb;
	obj_id 		   uuid;
	values_to_add  jsonb;
	json_path      text[];
	obj		 	   jsonb;
	new_obj		   jsonb;
	field_value    jsonb;
	access_token   jsonb;

BEGIN
	class := data->'class';
	IF (class IS NULL) THEN
		RAISE EXCEPTION 'The reclada object class is not specified';
   	END IF;
	
	obj_id := (data->>'id')::uuid;
	IF(obj_id IS NULL) THEN
		RAISE EXCEPTION 'There is no id';
	END IF;
	
	access_token := data->'access_token';
	SELECT api.reclada_object_list(format(
		'{"class": %s, "attrs": {}, "id": "%s", "access_token": %s}',
        class,
        obj_id,
        access_token
    	)::jsonb) -> 0 INTO obj;
    		
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
	
	field_value :=  data->'field';
	IF (field_value IS NULL) THEN
		RAISE EXCEPTION 'There is no field';
	END IF;
	json_path := format('{attrs, %s}', field_value);
	field_value := obj#>json_path;
	IF (field_value IS NULL) THEN
		RAISE EXCEPTION 'The object does not have this field';
	END IF;
		
	IF (field_value = 'null'::jsonb) THEN
		SELECT jsonb_set(obj, json_path, values_to_add) || format('{"access_token": %s}', access_token)::jsonb
		INTO new_obj;
	ELSE
		SELECT jsonb_set(obj, json_path, field_value || values_to_add) || format('{"access_token": %s}', access_token)::jsonb
		INTO new_obj;
	END IF;
	
	PERFORM api.reclada_object_update(new_obj);
END;
$$ LANGUAGE PLPGSQL VOLATILE;
