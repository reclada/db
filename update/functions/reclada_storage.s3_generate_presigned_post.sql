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
        Key=json_data["objectPath"],
        Fields={
            "Content-Type": json_data["fileType"],
        },
        Conditions=[
            {"Content-Type": json_data["fileType"]},
            ["content-length-range", 1, json_data["fileSize"]],
        ],
        ExpiresIn=3600,
    )

    return json.dumps(response)
$$ LANGUAGE 'plpython3u';