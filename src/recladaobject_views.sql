DROP VIEW IF EXISTS reclada.v_object;
CREATE OR REPLACE VIEW reclada.v_object
AS
    SELECT  obj.data,
			obj.data -> 'class' AS class_name,
			obj.data->'id' AS ID
		FROM reclada.object obj
			WHERE ((data->'revision')::numeric = (SELECT max((objrev.data->'revision')::numeric)
					FROM reclada.object objrev
					WHERE (objrev.data->'id' = obj.data->'id')
						AND (objrev.data->'isDeleted' = 'false')));
                

DROP VIEW IF EXISTS reclada.v_class;
CREATE OR REPLACE VIEW reclada.v_class
AS
    SELECT  data
		FROM reclada.v_object obj
   	 		WHERE (class_name = '"jsonschema"');

DROP FUNCTION IF EXISTS reclada_object.get_schema(jsonb);
CREATE OR REPLACE FUNCTION reclada_object.get_schema(class jsonb)
RETURNS jsonb AS $$
    SELECT data FROM reclada.v_class
    WHERE (data->'attrs'->'forClass' = class)
    LIMIT 1
$$ LANGUAGE SQL IMMUTABLE;
/*
DROP FUNCTION IF EXISTS reclada_object.get_object(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_object.get_object(class_name jsonb, objid jsonb)
RETURNS jsonb AS $$
    SELECT 	v.data
		FROM reclada.v_object v
			WHERE v.class_name = class_name
				AND v.data->'id' = objid
	LIMIT 1
$$ LANGUAGE SQL IMMUTABLE;
*/


	