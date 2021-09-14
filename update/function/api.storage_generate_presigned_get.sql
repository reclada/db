/*
 * Function api.storage_generate_presigned_get returns url for the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  objectId - id of the object
 *  accessToken - jwt token to authorize
 *
*/

DROP FUNCTION IF EXISTS api.storage_generate_presigned_get;
CREATE OR REPLACE FUNCTION api.storage_generate_presigned_get(data jsonb)
RETURNS jsonb AS $$
DECLARE
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

    -- TODO: check user's permissions for reclada object access?
    object_id := data->>'objectId';
    SELECT reclada_object.list(format(
        '{"class": "File", "attributes": {}, "GUID": "%s"}',
        object_id
    )::jsonb) -> 0 INTO object_data;

    SELECT payload
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
            's3_get_presigned_url_dev2',
            'eu-west-1'
            ),
        format('{
            "type": "get",
            "uri": "%s",
            "expiration": 3600}',
            object_data->'attributes'->>'uri'
            )::jsonb)
    INTO result;

    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;