
DROP FUNCTION IF EXISTS reclada_user.is_allowed;
CREATE OR REPLACE FUNCTION reclada_user.is_allowed(jsonb, text, text)
RETURNS boolean AS $$
BEGIN
    RETURN TRUE;
END;
$$ LANGUAGE PLPGSQL STABLE;