DROP FUNCTION IF EXISTS api.storage_generate_presigned_get(jsonb);
CREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)
RETURNS jsonb AS $$
DECLARE
    credentials  jsonb;
    object_data  jsonb;
    object_id    uuid;
    result       jsonb;
    user_info    jsonb;
BEGIN
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;

    -- TODO: check user's permissions for reclada object access?
    object_id := data->>'objectId';
    SELECT reclada_object.list(format(
        '{"class": "File", "attrs": {}, "id": "%s"}',
        object_id
    )::jsonb) -> 0 INTO object_data;

    SELECT reclada_storage.s3_generate_presigned_get(credentials, object_data) INTO result;
    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;
