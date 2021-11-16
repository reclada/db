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
 *  accessToken - jwt token to authorize
 * Optional parameters:
 *  bucketName - the name of S3 bucket
 *
*/
DROP FUNCTION IF EXISTS api.storage_generate_presigned_post;
CREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)
RETURNS jsonb AS $$
DECLARE
    user_info    jsonb;
    object_name  varchar;
    file_type    varchar;
    file_size    varchar;
    context      jsonb;
    bucket_name  varchar;
    url          varchar;
    result       jsonb;

BEGIN
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'generate presigned post', ''))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    object_name := data->>'objectName';
    file_type := data->>'fileType';
    file_size := data->>'fileSize';

    IF (object_name IS NULL) OR (file_type IS NULL) OR (file_size IS NULL) THEN
        RAISE EXCEPTION 'Parameters objectName, fileType and fileSize must be present';
    END IF;

    SELECT attrs
    FROM reclada.v_active_object
    WHERE class_name = 'Context'
    ORDER BY id DESC
    LIMIT 1
    INTO context;

    bucket_name := data->>'bucketName';

    SELECT payload::jsonb
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
                context->>'Lambda',
                context->>'Region'
        ),
        format('{
            "type": "post",
            "fileName": "%s",
            "fileType": "%s",
            "fileSize": "%s",
            "bucketName": "%s",
            "expiration": 3600}',
            object_name,
            file_type,
            file_size,
            bucket_name
            )::jsonb)
    INTO url;

    result = format(
        '{"uploadUrl": %s}',
        url
    )::jsonb;

    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;