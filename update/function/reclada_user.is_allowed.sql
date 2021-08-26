
DROP FUNCTION IF EXISTS reclada_user.is_allowed;
CREATE OR REPLACE FUNCTION reclada_user.is_allowed(jsonb, text, jsonb)
RETURNS boolean AS $$
BEGIN
    RETURN TRUE;
END;
$$ LANGUAGE PLPGSQL STABLE;