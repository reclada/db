/*
 * Function reclada_object.list_related returns the list of objects from the field of the specified object and the number of these objects.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the class of the object
 *  id - identifier of the object
 *  field - the name of the field containing the related object references (for multiple attributes separate fields by comma)
 *  relatedClass - the class of the related objects
 * Optional parameters:
 *  orderBy - list of jsons in the form of {"field": "field_name", "order": <"ASC"/"DESC">}.
 *      field - required value with name of property to order by
 *      order - optional value of the order; default is "ASC". Sorted by id in ascending order by default
 *  limit - the number or string "ALL", no more than this many objects will be returned. Default limit value is "ALL".
 *  offset - the number to skip this many objects before beginning to return objects. Default offset value is 0.
 *
*/

DROP FUNCTION IF EXISTS reclada_object.list_related;
CREATE OR REPLACE FUNCTION reclada_object.list_related(data jsonb)
RETURNS jsonb AS $$
DECLARE
    class          text;
    objid          uuid;
    field          text;
    related_class  text;
    obj            jsonb;
    list_of_ids    jsonb;
    cond           jsonb = '{}'::jsonb;
    order_by       jsonb;
    limit_         text;
    offset_        text;
    res            jsonb;

BEGIN
    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    objid := (data->>'GUID')::uuid;
    IF (objid IS NULL) THEN
        RAISE EXCEPTION 'The object GUID is not specified';
    END IF;

    field := data->>'field';
    IF (field IS NULL) THEN
        RAISE EXCEPTION 'The object field is not specified';
    END IF;

    related_class := data->>'relatedClass';
    IF (related_class IS NULL) THEN
        RAISE EXCEPTION 'The related class is not specified';
    END IF;

	SELECT v.data
	FROM reclada.v_active_object v
	WHERE v.obj_id = objid
	INTO obj;

    IF (obj IS NULL) THEN
        RAISE EXCEPTION 'There is no object with such id';
    END IF;

    list_of_ids := obj#>(format('{attributes, %s}', field)::text[]);
    IF (list_of_ids IS NULL) THEN
        RAISE EXCEPTION 'The object does not have this field';
    END IF;

    order_by := data->'orderBy';
    IF (order_by IS NOT NULL) THEN
        cond := cond || (format('{"orderBy": %s}', order_by)::jsonb);
    END IF;

    limit_ := data->>'limit';
    IF (limit_ IS NOT NULL) THEN
        cond := cond || (format('{"limit": "%s"}', limit_)::jsonb);
    END IF;

    offset_ := data->>'offset';
    IF (offset_ IS NOT NULL) THEN
        cond := cond || (format('{"offset": "%s"}', offset_)::jsonb);
    END IF;

    SELECT reclada_object.list(format(
        '{"class": "%s", "attributes": {}, "id": {"operator": "<@", "object": %s}}',
        related_class,
        list_of_ids
        )::jsonb || cond,
        true)
    INTO res;

    RETURN res;

END;
$$ LANGUAGE PLPGSQL STABLE;
