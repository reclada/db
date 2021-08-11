CREATE OR REPLACE FUNCTION api.auth_get_token(data JSONB)
RETURNS JSONB AS $$
    import requests, json

    json_data = json.loads(data)
    code = json_data.get("code")
    refresh_token = json_data.get("refresh_token")

    request_data = {}
    if code:
        request_data["grant_type"] = "authorization_code"
        request_data["code"] = code
    elif refresh_token:
        request_data["grant_type"] = "refresh_token"
        request_data["refresh_token"] = refresh_token

    settings = plpy.execute("select oidc_url, oidc_client_id from reclada.auth_setting", 1)
    if not settings:
        raise ValueError
    request_data["client_id"] = settings[0]["oidc_client_id"]

    token_url = f'{settings[0]["oidc_url"]}/token'
    response = requests.post(
        url=token_url,
        data=request_data,
    )
    response.raise_for_status()
    return response.text
$$ LANGUAGE 'plpython3u';