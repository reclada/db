DROP FUNCTION IF EXISTS api.storage_generate_presigned_post(jsonb);
CREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)
RETURNS jsonb AS $$
DECLARE
    bucket_name  varchar;
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
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    object_name := data->>'objectName';
    file_type := data->>'fileType';
    bucket_name := data->>'bucketName';
    SELECT uuid_generate_v4() INTO object_id;
    object_path := object_id;
    uri := 's3://' || bucket_name || '/' || object_path;

    -- TODO: remove checksum from required attrs for File class?
    SELECT reclada_object.create(format(
        '{"class": "File", "attrs": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "tempChecksum"}}',
        object_name,
        file_type,
        uri
    )::jsonb)->0 INTO object;

    SELECT payload::jsonb
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
            's3_get_presigned_url_test',
            'eu-west-1'
            ),
        format('{
            "type": "post",
            "bucketName": "%s",
            "fileName": "%s",
            "fileType": "%s",
            "fileSize": "%s",
            "expiration": 3600}',
            bucket_name,
            object_name,
            file_type,
            data->>'fileSize'
            )::jsonb)
    INTO url;

    result = format(
        '{"object": %s, "uploadUrl": %s}',
        object,
        url
    )::jsonb;

    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;