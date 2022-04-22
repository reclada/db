### Installation DB
1. Make sure, that you have:
    * psql (psql -V);
    * git (git --version);
    * python (python --version must be 3.X).
2. git clone:
    * ```git clone https://git.../db```
    * ```git clone https://git.../SciNLP```
    * ```git clone https://git.../reclada-runtime```
    * ```git clone https://git.../configurations```
    * ```git clone https://git.../components```
3. Create new environment configuration file (```my_environment.json```) in "configurations" or use existing (```commit``` and ```push``` are optional).
4. Create ```"configuration.json"``` for each component directory (db, SciNLP, reclada-runtime) if you want use custom configuration.
    > ***Note:*** for component "reclada-runtime" is necessary to use custom configuration for correct working (at least should edit ```"LAMBDA_NAME"```)
5. run ```cd components``` 
6. run ```python installer.py my_environment```
### Upgrade DB:
1. Upgrade code on file system;
2. (optional) Edit ```"configuration.json"``` for each component directory (db, SciNLP, reclada-runtime);
3. run ```cd components``` 
4. run ```python installer.py my_environment```
> ***Note:*** For component "db" should use only commits from branch "test" or "master", because every commit must has migration script. Commits without migration script (or incorrect migration script) are invalid.

### Auth usage:

To call stored functions use PostgREST API. 
All functions are inside `api` schema, and it is accessed by default.

1. Get auth url using `auth_get_login_url('{}')`
2. Open this url
3. Catch redirect back and parse `code` from URL
4. Exchange `code` to `access_token` using `auth_get_token('{"code": "49ed87e0..."}');`
5. Add `access_token` to all other requests
6. `refresh_token` also issued with `access_token`. Use `auth_get_token('{"refresh_token": "eyJhbGciOiJI..."}');` to get a new `access_token`.


### Storage usage:
#### File upload:

1. Login to `http://minio:9000/minio/login/` using `minio/password` as credentials
2. Create bucket with name `minio-bucket`
3. Save your storage credentials using PostgREST API:
   ```
   reclada_object_create('{
     "accessToken": "eyJhbGciOiJSUz...",
     "class": "S3Config",
     "attrs": {
       "endpointURL": "http://minio:9000",
       "accessKeyId": "minio",
       "secretAccessKey": "password",
       "bucketName": "minio-bucket"
     }
   }');
   ```
   You could also use Amazon S3 with your credentials, just specify `"regionName"` in `"attrs"` and remove `"endpointURL"`. Another S3-compatible services are not tested.
4. Generate presigned URL using PostgREST API:
   ```
   storage_generate_presigned_post('{
     "accessToken": "eyJhbGciOiJSUz...",
     "objectName": "file.txt",
     "fileType": "text/plain",
     "fileSize": 999999,
     "accessKeyId": "minio",
     "secretAccessKey": "password",
     "bucketName": "minio-bucket"
   }');
   ```
   A new reclada object of the File class will also be created.
5. Upload a file using generated URL.

#### File download:

Generate presigned URL using PostgREST API:
   ```
   storage_generate_presigned_get('{
     "accessToken": "eyJhbGciOiJSUz...",
     "objectId": "0f82c167..."
   }');
   ```
