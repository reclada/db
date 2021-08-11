CREATE OR REPLACE FUNCTION reclada_user.get_jwk(url VARCHAR)
RETURNS JSONB as $$
    import requests, json
    response = requests.get(f"{url}/certs")
    response.raise_for_status()
    return json.dumps(response.json()["keys"])
$$ LANGUAGE 'plpython3u';
