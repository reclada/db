CREATE OR REPLACE FUNCTION reclada_user.setup_keycloak(data JSONB)
RETURNS void AS $$
DECLARE
    oidc_url VARCHAR;
    jwk JSONB;
BEGIN
    -- check if allowed?
    oidc_url := format(
        '%s/auth/realms/%s/protocol/openid-connect',
        data->>'baseUrl', data->>'realm'
    );
    jwk := reclada_user.get_jwk(oidc_url);

    DELETE FROM reclada.auth_setting;
    INSERT INTO reclada.auth_setting
        (oidc_url, oidc_client_id, oidc_redirect_url, jwk)
    VALUES
        (oidc_url, data->>'clientId', data->>'redirectUrl', jwk);
END;
$$ LANGUAGE PLPGSQL VOLATILE;
