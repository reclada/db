DROP FUNCTION IF EXISTS reclada_storage.s3_generate_presigned_post(jsonb, jsonb);
CREATE OR REPLACE FUNCTION reclada_storage.s3_generate_presigned_post(data JSONB, credentials JSONB)
RETURNS JSONB AS $$
    import json

    import boto3

    json_data = json.loads(data)
    json_credentials = json.loads(credentials)["attrs"]

    s3_client = boto3.client(
        service_name="s3",
        endpoint_url=json_credentials.get("endpointURL"),
        region_name=json_credentials.get("regionName"),
        aws_access_key_id=json_credentials["accessKeyId"],
        aws_secret_access_key=json_credentials["secretAccessKey"],
    )

    response = s3_client.generate_presigned_post(
        Bucket=json_credentials["bucketName"],
        Key=json_data["object_path"],
        Fields={
            "Content-Type": json_data["file_type"],
        },
        Conditions=[
            {"Content-Type": json_data["file_type"]},
            ["content-length-range", 1, json_data["file_size"]],
        ],
        ExpiresIn=3600,
    )

    return json.dumps(response)
$$ LANGUAGE 'plpython3u';

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
