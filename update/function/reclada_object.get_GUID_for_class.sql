DROP FUNCTION IF EXISTS reclada_object.get_GUID_for_class;
CREATE OR REPLACE FUNCTION reclada_object.get_GUID_for_class(class text)
RETURNS uuid AS $$
    SELECT obj_id
        from reclada.v_class_lite
            where for_class = class
$$ LANGUAGE SQL STABLE;