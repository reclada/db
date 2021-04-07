### Installation
1. Add `keycloak` to your hosts file as domain for `127.0.0.1`
2. Build: `docker-compose build`
3. Start: `docker-compose up -d`
4. Initialize DB: `docker-compose exec postgres psql postgres postgres -f scheme.sql -f functions.sql -f data.sql`
5. Create keycloak admin: `docker-compose exec keycloak /opt/jboss/keycloak/bin/add-user-keycloak.sh -u admin -p password`
6. Restart keycloak: `docker-compose restart keycloak`
7. Login to `http://keycloak:8080/auth/admin/`
8. Create new realm for reaclada with name `reclada-users`
9. Create client with name `reclada-client`. Set root url to location of UI `http://reclada.test`
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