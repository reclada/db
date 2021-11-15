/*
 * Function api.storage_generate_presigned_get returns url for the object.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  objectId - the identifier of the object
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
    context      jsonb;

BEGIN
    SELECT reclada_user.auth_by_token(data->>'accessToken') INTO user_info;
    data := data - 'accessToken';

    IF (NOT(reclada_user.is_allowed(user_info, 'generate presigned get', ''))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned get';
    END IF;

    -- TODO: check user's permissions for reclada object access?
    object_id := data->>'objectId';
    SELECT reclada_object.list(format(
        '{"class": "File", "attributes": {}, "GUID": "%s"}',
        object_id
    )::jsonb) -> 0 INTO object_data;

    IF (object_data IS NULL) THEN
		RAISE EXCEPTION 'There is no object with such id';
	END IF;

    SELECT attrs
    FROM reclada.v_active_object
    WHERE class_name = 'Context'
    ORDER BY created_time DESC
    LIMIT 1
    INTO context;

    SELECT payload
    FROM aws_lambda.invoke(
        aws_commons.create_lambda_function_arn(
            context->>'Lambda',
            context->>'Region'
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