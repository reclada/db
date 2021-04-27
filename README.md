### Installation
1. Add `keycloak` and `minio` to your hosts file as domain for `127.0.0.1`
2. Build: `docker-compose build`
3. Start: `docker-compose up -d`
4. Initialize DB: `docker-compose exec postgres psql postgres postgres -f scheme.sql -f functions.sql -f data.sql`
5. Create keycloak admin: `docker-compose exec keycloak /opt/jboss/keycloak/bin/add-user-keycloak.sh -u admin -p password`
6. Restart keycloak: `docker-compose restart keycloak`
7. Login to `http://keycloak:8080/auth/admin/`
8. Create new realm for reaclada with name `reclada-users`
9. Create client with name `reclada-client`. Set root url to location of UI `http://reclada.test`. Create a new user, set him a password.
10. Configure usage of keycloak in db. Connect to postgresql and call function:
    ```
    select reclada_user.setup_keycloak('{
        "base_url": "http://keycloak:8080", 
        "realm": "reclada-users",
        "client_id": "reclada-client",
        "redirect_url": "http://reclada.test"
    }');
    ```

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
     "access_token": "eyJhbGciOiJSUz...",
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
     "access_token": "eyJhbGciOiJSUz...",
     "object_name": "file.txt",
     "file_type": "text/plain",
     "file_size": 999999,
     "access_key_id": "minio",
     "secret_access_key": "password",
     "bucket_name": "minio-bucket"
   }');
   ```
   A new reclada object of the File class will also be created.
5. Upload a file using generated URL.

#### File download:

Generate presigned URL using PostgREST API:
   ```
   storage_generate_presigned_get('{
     "access_token": "eyJhbGciOiJSUz...",
     "object_id": "0f82c167..."
   }');
   ```