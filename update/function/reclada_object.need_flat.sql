
/*
    returns true if need flat
    else false
*/

DROP FUNCTION IF EXISTS reclada_object.need_flat;
CREATE OR REPLACE FUNCTION reclada_object.need_flat(_class_name text)
RETURNS bool AS $$
    select exists
        (
            select true as r
                from reclada.v_object_display d
                join reclada_object.get_guid_for_class(_class_name) tf
                    on tf.obj_id = d.class_guid
                where d.table is not null
        )
$$ LANGUAGE SQL STABLE;