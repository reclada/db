CREATE TABLE reclada.object(
    data    jsonb   NOT NULL
);

CREATE SCHEMA reclada_user;
CREATE SCHEMA reclada_revision;
CREATE SCHEMA reclada_object;
CREATE SCHEMA reclada_storage;
CREATE SCHEMA reclada_notification;
CREATE SEQUENCE reclada_revisions;


CREATE TABLE reclada.auth_setting(
    oidc_url VARCHAR,
    oidc_client_id VARCHAR,
    oidc_redirect_url VARCHAR,
    jwk JSONB
);