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