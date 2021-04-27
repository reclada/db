DROP FUNCTION IF EXISTS api.list_drop(jsonb);

CREATE OR REPLACE FUNCTION api.list_drop(data jsonb)
RETURNS void AS $$
DECLARE  
	class          jsonb;
	obj_id 		   uuid;
	value_to_drop  jsonb; 
	new_value 	   jsonb;
	json_path      text[];
	obj		 	   jsonb;
	new_obj		   jsonb;
	field_value    jsonb;

	BEGIN
		class := data->'class';
		IF (class IS NULL) THEN
			RAISE EXCEPTION 'The reclada object class is not specified';
   		END IF;
	
   	
		obj_id := (data->>'id')::uuid;
		IF(obj_id IS NULL) THEN
        	RAISE EXCEPTION 'The is no id';
    	END IF;
	
		SELECT reclada_object.list(format(
			'{"class": %s, "attrs": {}, "id": "%s"}',
        	class,
        	obj_id
    		)::jsonb) -> 0 INTO obj;
    	
    	IF (obj IS NULL) THEN
        	RAISE EXCEPTION 'The is no object with such id';
    	END IF;
    	
    	
    	json_path := format('{attrs, %s}', data->'field');
    
		value_to_drop := data->'value';
		IF (value_to_drop IS NULL) THEN
        	RAISE EXCEPTION 'There value should not be null';
    	END IF;
    	
    	field_value := obj#>json_path;
		    
    	SELECT jsonb_agg(elems)
		FROM 
			jsonb_array_elements(field_value) elems
		WHERE 
			NOT (elems IN ( 
				SELECT jsonb_array_elements(value_to_drop)))
		INTO new_value;
		
		
		SELECT jsonb_set(obj, json_path, new_value) || format('{"access_token": "%s"}', data->>'access_token')::jsonb
		INTO new_obj;
	
		PERFORM api.reclada_object_update(new_obj);
	
	END;
$$ LANGUAGE PLPGSQL VOLATILE;

