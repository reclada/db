CREATE OR REPLACE FUNCTION reclada_storage.s3_generate_presigned_post(data JSONB)
RETURNS JSONB AS $$
    import json

    import boto3

    json_data = json.loads(data)

    s3_client = boto3.client(
        service_name="s3",
        endpoint_url=json_data.get("endpoint_url"),
        region_name=json_data.get("region_name"),
        aws_access_key_id=json_data["access_key_id"],
        aws_secret_access_key=json_data["secret_access_key"],
    )

    response = s3_client.generate_presigned_post(
        Bucket=json_data["bucket_name"],
        Key=json_data["object_name"],
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
