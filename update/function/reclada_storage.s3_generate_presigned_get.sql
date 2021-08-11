
DROP FUNCTION IF EXISTS reclada_storage.s3_generate_presigned_get(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_storage.s3_generate_presigned_get(credentials JSONB, object_data JSONB)
RETURNS JSONB AS $$
    import json
    from urllib.parse import urlparse

    import boto3

    json_credentials = json.loads(credentials)["attrs"]
    json_object_data = json.loads(object_data)["attrs"]

    parsed_uri = urlparse(json_object_data["uri"])
    bucket = parsed_uri.netloc
    key = parsed_uri.path.lstrip("/")

    s3_client = boto3.client(
        service_name="s3",
        endpoint_url=json_credentials.get("endpointURL"),
        region_name=json_credentials.get("regionName"),
        aws_access_key_id=json_credentials["accessKeyId"],
        aws_secret_access_key=json_credentials["secretAccessKey"],
    )

    url = s3_client.generate_presigned_url(
        ClientMethod="get_object",
        Params={
            "Bucket": bucket,
            "Key": key,
        },
        ExpiresIn=3600,
    )

    return json.dumps({"url": url})
$$ LANGUAGE 'plpython3u';
