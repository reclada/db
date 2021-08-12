CREATE OR REPLACE FUNCTION reclada_object.get_schema(class text)
RETURNS jsonb AS $$
    SELECT data FROM reclada.v_class
    WHERE (data->'attrs'->>'forClass' = class)
    LIMIT 1
$$ LANGUAGE SQL STABLE;