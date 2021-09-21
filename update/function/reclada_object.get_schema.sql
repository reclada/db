DROP FUNCTION IF EXISTS reclada_object.get_schema;
CREATE OR REPLACE FUNCTION reclada_object.get_schema(class text)
RETURNS jsonb AS $$
    SELECT data FROM reclada.v_class
        WHERE for_class = class
            LIMIT 1
$$ LANGUAGE SQL STABLE;