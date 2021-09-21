
/*
 * Function api.storage_generate_presigned_post creates File object and returns this object with url.
 * Output is jsonb like this: {
 *     "uploadUrl": {"url": "...", "fields": {"key": "..."}}
 *     }
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  objectName - name of the object
 *  fileType - id of the object
 *  fileSize - size of the object
 *  bucketName - name of Amazon S3 bucket
 *  accessToken - jwt token to authorize
 *
*/
DROP FUNCTION IF EXISTS api.storage_generate_presigned_post;
CREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)
RETURNS jsonb AS $$
DECLARE
    --bucket_name  varchar;
    lambda_name  varchar;
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
    --bucket_name := data->>'bucketName';

    SELECT attrs->>'name'
    FROM reclada.v_active_object
    WHERE class_name = 'Lambda'
    ORDER BY created_time DESC
    LIMIT 1
    INTO lambda_name;

    /*
    SELECT uuid_generate_v4() INTO object_id;
    object_path := object_id;
    uri := 's3://' || bucket_name || '/' || object_path;

    -- TODO: remove checksum from required attrs for File class?
    SELECT reclada_object.create(format(
        '{"class": "File", "attributes": {"name": "%s", "mimeType": "%s", "uri": "%s", "checksum": "tempChecksum"}}',
        object_name,
        file_type,
        uri
    )::jsonb)->0 INTO object;
    */

    SELECT payload::jsonb
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
                format('%s', lambda_name),
                'eu-west-1'
        ),
        format('{
            "type": "post",
            "fileName": "%s",
            "fileType": "%s",
            "fileSize": "%s",
            "expiration": 3600}',
            object_name,
            file_type,
            data->>'fileSize'
            )::jsonb)
    INTO url;

    result = format(
        --'{"object": %s, "uploadUrl": %s}',
        --object,
        '{"uploadUrl": %s}',
        url
    )::jsonb;

    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;