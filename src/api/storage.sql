DROP FUNCTION IF EXISTS api.storage_generate_presigned_post(jsonb);
CREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)
RETURNS jsonb AS $$
DECLARE
    bucket_name  varchar;
    credentials  jsonb;
    file_type    varchar;
    object       jsonb;
    object_id    uuid;
    object_name  varchar;
    object_path  varchar;
    result       jsonb;
    user_info    jsonb;
    uri          varchar;
    url          varchar;
BEGIN
    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;
    data := data - 'access_token';

    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;

    object_name := data->>'object_name';
    file_type := data->>'file_type';
    bucket_name := credentials->'attrs'->>'bucketName';
    SELECT uuid_generate_v4() INTO object_id;
    object_path := object_id;
    uri := 's3://' || bucket_name || '/' || object_path;

    -- TODO: remove checksum from required attrs for File class?
    SELECT reclada_object.create(format(
        '{"class": "File", "attrs": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "temp_checksum"}}',
        object_name,
        file_type,
        uri
    )::jsonb) INTO object;

    data := data || format('{"object_path": "%s"}', object_path)::jsonb;
    SELECT reclada_storage.s3_generate_presigned_post(data, credentials)::jsonb INTO url;

    result = format(
        '{"object": %s, "upload_url": %s}',
        object,
        url
    )::jsonb;
    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

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
    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;
    data := data - 'access_token';

    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    SELECT reclada_object.list('{"class": "S3Config", "attrs": {}}')::jsonb -> 0 INTO credentials;

    -- TODO: check user's permissions for reclada object access?
    object_id := data->>'object_id';
    SELECT reclada_object.list(format(
        '{"class": "File", "attrs": {}, "id": "%s"}',
        object_id
    )::jsonb) -> 0 INTO object_data;

    SELECT reclada_storage.s3_generate_presigned_get(credentials, object_data) INTO result;
    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;
