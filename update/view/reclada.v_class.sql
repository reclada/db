CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT  data
	FROM reclada.v_object obj
   	WHERE (class_name = 'jsonschema');