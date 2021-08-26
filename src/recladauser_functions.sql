DROP FUNCTION IF EXISTS reclada_user.auth_by_token(uuid);

/* Just for demo */
CREATE OR REPLACE FUNCTION reclada_user.auth_by_token(token VARCHAR)
RETURNS JSONB AS $$
    SELECT '{}'::jsonb
$$ LANGUAGE SQL IMMUTABLE;
/*
CREATE OR REPLACE FUNCTION reclada_user.auth_by_token(token VARCHAR)
RETURNS JSONB AS $$
DECLARE
    current_jwk JSONB;
BEGIN
    SELECT jwk INTO current_jwk FROM reclada.auth_setting LIMIT 1;
    IF current_jwk IS NULL THEN
        RETURN jsonb_build_object('sub', ''); -- stub user
    ELSE
        RETURN reclada_user.parse_token(token, current_jwk);
    end if;
END;
$$ LANGUAGE PLPGSQL STABLE;
*/


DROP FUNCTION IF EXISTS reclada_user.is_allowed;
CREATE OR REPLACE FUNCTION reclada_user.is_allowed(jsonb, text, jsonb)
RETURNS boolean AS $$
BEGIN
    RETURN TRUE;
END;
$$ LANGUAGE PLPGSQL STABLE;


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


CREATE OR REPLACE FUNCTION reclada_user.parse_token(access_token VARCHAR, jwk JSONB)
RETURNS JSONB AS $$
    import jwt, json
    first_jwk = json.loads(jwk)[0]
    cert = jwt.algorithms.RSAAlgorithm.from_jwk(first_jwk)
    res = jwt.decode(
        access_token,
        options={"verify_signature": True, "verify_aud": False},
        # audience="account",
        key=cert, algorithms=[first_jwk["alg"]]
    )
    return json.dumps(res)
$$ LANGUAGE 'plpython3u';
