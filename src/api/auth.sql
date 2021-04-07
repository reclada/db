CREATE OR REPLACE FUNCTION api.auth_get_login_url(data JSONB)
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


CREATE OR REPLACE FUNCTION api.auth_get_token(data JSONB)
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