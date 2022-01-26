DROP FUNCTION IF EXISTS reclada_object.get_archive_status_obj_id;
CREATE OR REPLACE FUNCTION reclada_object.get_archive_status_obj_id()
RETURNS uuid AS $$
    select obj_id 
        from reclada.v_object_status 
            where caption = 'archive'
$$ LANGUAGE SQL IMMUTABLE;