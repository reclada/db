DROP FUNCTION IF EXISTS api.storage_generate_presigned_post(jsonb);
CREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data jsonb)
RETURNS jsonb AS $$
DECLARE
    attrs      jsonb;
    user_info  jsonb;
    result     jsonb;
BEGIN
    SELECT reclada_user.auth_by_token(data->>'access_token') INTO user_info;
    data := data - 'access_token';

    IF(NOT(reclada_user.is_allowed(user_info, 'generate presigned post', '{}'))) THEN
        RAISE EXCEPTION 'Insufficient permissions: user is not allowed to %', 'generate presigned post';
    END IF;

    SELECT reclada_storage.s3_generate_presigned_post(data) INTO result;
    RETURN result;
END;
$$ LANGUAGE PLPGSQL VOLATILE;