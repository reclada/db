/*
 * Function reclada.get_сhilds returns all children's GUIDs of the object conected by parent_id field.
 * Required parameters:
 *  _obj_id - root object GUID
 */

DROP FUNCTION IF EXISTS reclada.get_сhilds;
CREATE OR REPLACE FUNCTION reclada.get_сhilds(_obj_id uuid)
RETURNS SETOF uuid AS $$
    WITH RECURSIVE temp1 (id,obj_id,parent,class_name,level) AS (
        SELECT
            id,
            obj_id,
            parent_id,
            class_name,
            1
        FROM v_active_object vao 
        WHERE obj_id =_obj_id
            UNION 
        SELECT
            t2.id,
            t2.obj_id,
            t2.parent_id,
            t2.class_name,
            level+1
        FROM v_active_object t2 JOIN temp1 t1 ON t1.obj_id=t2.parent_id
    )
    SELECT obj_id FROM temp1
$$ LANGUAGE SQL VOLATILE;