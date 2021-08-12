DROP FUNCTION IF EXISTS reclada_user.auth_by_token(uuid);
/* Just for demo */
CREATE OR REPLACE FUNCTION reclada_user.auth_by_token(token VARCHAR)
RETURNS JSONB AS $$
    SELECT '{}'::jsonb
$$ LANGUAGE SQL IMMUTABLE;