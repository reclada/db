DROP FUNCTION IF EXISTS reclada_user.auth_by_token(uuid);
CREATE OR REPLACE FUNCTION reclada_user.auth_by_token(token uuid)
RETURNS uuid AS $$
BEGIN
    RETURN uuid_generate_v4();
END;
$$ LANGUAGE PLPGSQL STABLE;

DROP FUNCTION IF EXISTS reclada_user.is_allowed(uuid, text, jsonb);
CREATE OR REPLACE FUNCTION reclada_user.is_allowed(uuid, text, jsonb)
RETURNS boolean AS $$
BEGIN
    RETURN TRUE;
END;
$$ LANGUAGE PLPGSQL STABLE;
