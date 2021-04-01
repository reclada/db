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


---------------------------------------
CREATE OR REPLACE FUNCTION reclada_user.get_jwk(url VARCHAR)
RETURNS JSONB as $$
import requests
response = requests.get(url)
response.raise_for_status()
return response.json()["keys"]
$$ LANGUAGE 'plpython3u';


CREATE OR REPLACE FUNCTION reclada_user.setup_keycloak(data JSONB)
RETURNS void AS $$
DECLARE
    cert_url VARCHAR;
    token_url VARCHAR;
    jwk JSONB;
BEGIN
    -- check if allowed?
    cert_url := format(
        '%s/auth/realms/%s/protocol/openid-connect/certs',
        data->>'base_url', data->>'realm'
    );
    token_url := format(
        '%s/auth/realms/%s/protocol/openid-connect/token',
        data->>'base_url', data->>'realm'
    );
    jwk := reclada_user.get_jwk(cert_url);

    DELETE FROM reclada.auth_setting;
    INSERT INTO reclada.auth_setting
        (oidc_cert_url, oidc_token_url, oidc_client_id, oidc_redirect_url, jwk)
    VALUES
        (cert_url, token_url, data->>'client_id', data->>'redirect_url', jwk);
END;
$$ LANGUAGE PLPGSQL VOLATILE;


CREATE OR REPLACE FUNCTION reclada_user.disable_auth(data JSONB)
RETURNS void AS $$
BEGIN
    DELETE FROM reclada.auth_setting;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

CREATE OR REPLACE FUNCTION reclada_user.refresh_jwk(data JSONB)
RETURNS void AS $$
DECLARE
    cert_url VARCHAR;
    new_jwk JSONB;
BEGIN
    SELECT oidc_cert_url INTO cert_url FROM reclada.auth_setting FOR UPDATE;
    new_jwk := reclada_user.get_jwk(cert_url);
    UPDATE reclada.auth_setting SET jwk=new_jwk WHERE oidc_cert_url=cert_url;
END;
$$ LANGUAGE PLPGSQL VOLATILE;