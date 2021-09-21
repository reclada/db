DROP FUNCTION IF EXISTS reclada_object.get_default_user_obj_id;
CREATE OR REPLACE FUNCTION reclada_object.get_default_user_obj_id()
RETURNS uuid AS $$
    select obj_id 
        from reclada.v_user 
            where login = 'dev'
$$ LANGUAGE SQL STABLE;