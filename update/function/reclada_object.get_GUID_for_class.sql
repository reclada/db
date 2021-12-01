DROP FUNCTION IF EXISTS reclada_object.get_guid_for_class;
CREATE OR REPLACE FUNCTION reclada_object.get_guid_for_class(class text)
RETURNS TABLE(obj_id uuid) AS $$
    SELECT obj_id
        from reclada.v_class_lite
            where for_class = class
$$ LANGUAGE SQL STABLE;