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
    import requests, json
    response = requests.get(f"{url}/certs")
    response.raise_for_status()
    return json.dumps(response.json()["keys"])
$$ LANGUAGE 'plpython3u';


CREATE OR REPLACE FUNCTION reclada_user.setup_keycloak(data JSONB)
RETURNS void AS $$
DECLARE
    oidc_url VARCHAR;
    jwk JSONB;
BEGIN
    -- check if allowed?
    oidc_url := format(
        '%s/auth/realms/%s/protocol/openid-connect',
        data->>'base_url', data->>'realm'
    );
    jwk := reclada_user.get_jwk(oidc_url);

    DELETE FROM reclada.auth_setting;
    INSERT INTO reclada.auth_setting
        (oidc_url, oidc_client_id, oidc_redirect_url, jwk)
    VALUES
        (oidc_url, data->>'client_id', data->>'redirect_url', jwk);
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
    current_oidc_url VARCHAR;
    new_jwk JSONB;
BEGIN
    SELECT oidc_url INTO current_oidc_url FROM reclada.auth_setting FOR UPDATE;
    new_jwk := reclada_user.get_jwk(current_oidc_url);
    UPDATE reclada.auth_setting SET jwk=new_jwk WHERE oidc_url=current_oidc_url;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

CREATE OR REPLACE FUNCTION reclada_user.get_login_url(data JSONB)
RETURNS JSONB AS $$
DECLARE
    base_url VARCHAR;
    client_id VARCHAR;
BEGIN
    SELECT oidc_url, oidc_client_id INTO base_url, client_id
        FROM reclada.auth_setting;
    IF base_url IS NULL THEN
        RETURN jsonb_build_object('login_url', NULL);
    ELSE
        RETURN jsonb_build_object('login_url', format(
            '%s/auth?client_id=%s&response_type=code',
            base_url, client_id
        ));
    END IF;
END;
$$ LANGUAGE PLPGSQL VOLATILE;


CREATE OR REPLACE FUNCTION reclada_user.get_token(data JSONB)
RETURNS JSONB AS $$
    import requests, json
    code = json.loads(data)["code"]
    settings = plpy.execute("select oidc_url, oidc_client_id from reclada.auth_setting", 1)
    if not settings:
        raise ValueError

    token_url = f'{settings[0]["oidc_url"]}/token'
    response = requests.post(
        token_url,
        data={
            "code": code,
            "grant_type": "authorization_code",
            "client_id": settings[0]["oidc_client_id"],
        }
    )
    response.raise_for_status()
    return response.text
$$ LANGUAGE 'plpython3u';