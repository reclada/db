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
                
