

CREATE OR REPLACE FUNCTION reclada_user.disable_auth(data JSONB)
RETURNS void AS $$
BEGIN
    DELETE FROM reclada.auth_setting;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

CREATE OR REPLACE FUNCTION reclada_user.refresh_jwk(data JSONB)
RETURNS void AS $$
DECLARE
    current_oidc_url VARCHAR;
    new_jwk JSONB;
BEGIN
    SELECT oidc_url INTO current_oidc_url FROM reclada.auth_setting FOR UPDATE;
    new_jwk := reclada_user.get_jwk(current_oidc_url);
    UPDATE reclada.auth_setting SET jwk=new_jwk WHERE oidc_url=current_oidc_url;
END;
$$ LANGUAGE PLPGSQL VOLATILE;