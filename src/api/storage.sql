CREATE OR REPLACE FUNCTION api.storage_generate_presigned_post(data JSONB)
RETURNS JSONB AS $$
    import json

    import boto3

    json_data = json.loads(data)

    s3_client = boto3.client(
        service_name="s3",
        endpoint_url="",
        region_name="",
        aws_access_key_id="",
        aws_secret_access_key="",
    )

    response = plpy.execute("select reclada_storage.s3_generate_presigned_post", 1)

    response = s3_client.generate_presigned_post(
        Bucket=json_data["bucket_name"],
        Key=json_data["object_name"],
        Fields={
            "Content-Type": json_data["file_type"],
        },
        Conditions=[
            {"Content-Type": json_data["file_type"]},
            ["content-length-range", 1, json_data["size"]],
        ],
        ExpiresIn=3600,
    )

    return response
$$ LANGUAGE 'plpython3u';
