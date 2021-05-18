/*
 * Function api.reclada_object_list_related returns the list of elements from the field of the specified object.
 * Required parameters:
 *  class - the class of the object
 *  id - identifier of the object
 * field - the name of the field
 * access_token - jwt token to authorize
 *
*/

DROP FUNCTION IF EXISTS api.reclada_object_list_related(jsonb);
CREATE OR REPLACE FUNCTION api.reclada_object_list_related(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          jsonb;
    field          jsonb;
    obj_id         uuid;
    obj            jsonb;
    res            jsonb;
    access_token   text;

BEGIN
    class := data->'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    obj_id := (data->>'id')::uuid;
    IF (obj_id IS NULL) THEN
        RAISE EXCEPTION 'There is no object id';
    END IF;

    access_token := data->>'accessToken';
    SELECT (api.reclada_object_list(format(
        '{"class": %s, "attrs": {}, "id": "%s", 'accessToken': "%s"}',
        class,
        obj_id,
        access_token
        )::jsonb)) -> 0 INTO obj;

    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    field := data->'field';
    IF (field IS NULL) THEN
        RAISE EXCEPTION 'There is no field';
    END IF;

    res := obj#>(format('{attrs, %s}', field)::text[]);
    IF (res IS NULL) THEN
        RAISE EXCEPTION 'The object does not have this field';
    END IF;
    RETURN res;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

select * from reclada.object T
where T.data->>'class' = 'DataSet'
order by T.data->>'class', T.data->>'id', T.data->>'revision' DESC;

select api.reclada_object_list_related('{"class":"File","id":"ad14511d-6da8-4cac-8176-6bf725d6b3ab","field":"tags","accessToken":"eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJKSE9iaU1rcU1tRURvbGJ1ZlFjUXBLRDJqZ0gxTWdEaGxIeGx0SWY5Mkg4In0.eyJleHAiOjE2NDQ0ODExMTksImlhdCI6MTYxODU2MzA1NywiYXV0aF90aW1lIjoxNjE4NTYxMTE5LCJqdGkiOiI1NjM0YjQwMy0xZDZjLTQyNjItYTYxNy1jYmE3YTE2NTcxODkiLCJpc3MiOiJodHRwOi8va2V5Y2xvYWs6ODA4MC9hdXRoL3JlYWxtcy9yZWNsYWRhLXVzZXJzIiwiYXVkIjoiYWNjb3VudCIsInN1YiI6ImNiZmUxNWMxLWM2MmUtNDIxZi1iZjlhLTZhY2I4ZTc1M2EyYSIsInR5cCI6IkJlYXJlciIsImF6cCI6InJlY2xhZGEtY2xpZW50Iiwic2Vzc2lvbl9zdGF0ZSI6IjU0MTBhZTFmLTZhNzEtNDQ0NC1hZmIzLThlNjNiY2EzNjFmYiIsImFjciI6IjAiLCJhbGxvd2VkLW9yaWdpbnMiOlsiaHR0cDovL3JlY2xhZGEudGVzdCJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJkZWZhdWx0LXJvbGVzLXJlY2xhZGEtdXNlcnMiLCJ1bWFfYXV0aG9yaXphdGlvbiJdfSwicmVzb3VyY2VfYWNjZXNzIjp7ImFjY291bnQiOnsicm9sZXMiOlsibWFuYWdlLWFjY291bnQiLCJtYW5hZ2UtYWNjb3VudC1saW5rcyIsInZpZXctcHJvZmlsZSJdfX0sInNjb3BlIjoicHJvZmlsZSBlbWFpbCIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwicHJlZmVycmVkX3VzZXJuYW1lIjoiYWxleCJ9.gZfKrWN5vdNKAVNJ6tfJ8-SX0kGgmkuthKxf0hgf7gjBvRPpRSw7Yo1cw5GL_CV8mZGP18sX7_cFet5OyeEhwXfKFAghKC7FQbTNCQErJKjfvK1ft25wD4hp-c1hWg9PPyh41Lh6hgGlcQfvNWHmpIVPMuAKiYwtevPQ_Bku0BjkfBRJjDcBtqJ3RNtLW6LKLimmXDbGISVIfkbGCxBFMzpa3k0ovGkgqdhxW_KNVFPomH_BPi6_YqX1kGIoBUTf2E-Rg5vO0RuUEXmtf55kd3XJ_HtiSHcd-4kCMagyVccSudPlGgGMvSPL0HVbH8i9wN_igSbc3vN9e3aWueqkCQ"}'::jsonb);
