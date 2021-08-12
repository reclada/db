CREATE OR REPLACE VIEW reclada.v_object
AS
    SELECT  obj.data, -- собрать json
			obj.class AS class_name,
			coalesce((obj.obj_id_int)::text,('"'||obj.obj_id||'"'):: text) AS id,
			obj.obj_id_int as obj_id_int	,
			obj.obj_id	 as obj_id		

	FROM reclada.object obj
	WHERE obj.revision = 
	(
		SELECT max((objrev.revision))
			FROM reclada.object objrev
			WHERE 
				(
					objrev.obj_id = obj.obj_id
					or objrev.obj_id_int = obj.obj_id_int
				)
				AND objrev.status = 0
	);
