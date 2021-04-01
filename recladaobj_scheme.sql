CREATE TABLE reclada.object(
    data    jsonb   NOT NULL
);
CREATE schema reclada_object;
CREATE schema reclada_user;
CREATE schema reclada_revision;
CREATE SEQUENCE reclada_revisions;


CREATE TABLE reclada.auth_setting(
    oidc_cert_url VARCHAR,
    oidc_token_url VARCHAR,
    oidc_client_id VARCHAR,
    oidc_redirect_url VARCHAR,
    jwk JSONB
);