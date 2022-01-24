/*
 * Function reclada_object.create_subclass creates subclass.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  class - the name of parent class
 *  attributes - the attributes of objects of the class. The field contains:
 *      forClass - the name of class to create
 *      schema - the schema for the class
 */

DROP FUNCTION IF EXISTS reclada_object.create_subclass;
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(data jsonb)
RETURNS VOID AS $$
DECLARE
    class           text;
    new_class       text;
    attrs           jsonb;
    class_schema    jsonb;
    version_        integer;
    class_guid      uuid;
    _uniFields      jsonb;
    _idx_name       text;
    _f_list         text;
    _partial_clause text;
    _field_name     text;
BEGIN

    class := data->>'class';
    IF (class IS NULL) THEN
        RAISE EXCEPTION 'The reclada object class is not specified';
    END IF;

    attrs := data->'attributes';
    IF (attrs IS NULL) THEN
        RAISE EXCEPTION 'The reclada object must have attributes';
    END IF;

    new_class = attrs->>'newClass';

    SELECT reclada_object.get_schema(class) INTO class_schema;

    IF (class_schema IS NULL) THEN
        RAISE EXCEPTION 'No json schema available for %', class;
    END IF;

    SELECT max(version) + 1
    FROM reclada.v_class_lite v
    WHERE v.for_class = new_class
    INTO version_;

    version_ := coalesce(version_,1);
    class_schema := class_schema->'attributes'->'schema';

    SELECT obj_id
    FROM reclada.v_class
    WHERE for_class = class
    ORDER BY version DESC
    LIMIT 1
    INTO class_guid;

    PERFORM reclada_object.create(format('{
        "class": "jsonschema",
        "attributes": {
            "forClass": "%s",
            "version": "%s",
            "schema": {
                "type": "object",
                "properties": %s,
                "required": %s
            }
        },
        "parentGUID" : "%s"
    }',
    new_class,
    version_,
    (class_schema->'properties') || coalesce((attrs->'properties'),'{}'::jsonb),
    (SELECT jsonb_agg(el) FROM (
        SELECT DISTINCT pg_catalog.jsonb_array_elements(
            (class_schema -> 'required') || coalesce((attrs -> 'required'),'{}'::jsonb)
        ) el) arr),
    class_guid
    )::jsonb);

    IF ( jsonb_typeof(attrs->'dupChecking') = 'array' ) THEN
        FOR _uniFields IN (
            SELECT jsonb_array_elements(attrs->'dupChecking')->'uniFields'
        ) LOOP
            IF ( jsonb_typeof(_uniFields) = 'array' ) THEN
                SELECT
                    reclada.get_unifield_index_name( array_agg(f ORDER BY f)) AS idx_name, 
                    string_agg('(attributes ->> ''' || f || ''')','||' ORDER BY f) AS fields_list,
                    string_agg('attributes ->> ''' || f || ''' IS NOT NULL',' AND ' ORDER BY f) AS partial_clause
                FROM (
                    SELECT jsonb_array_elements_text (_uniFields::jsonb) f
                ) a
                    INTO _idx_name, _f_list;
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_catalog.pg_indexes pi2 
                    WHERE schemaname ='reclada' AND tablename ='object' AND indexname =_idx_name
                ) THEN
                    EXECUTE E'CREATE INDEX ' || _idx_name || ' ON reclada.object USING HASH ((' || _f_list || ')) WHERE ' || _partial_clause;
                END IF;
            END IF;
        END LOOP;
        PERFORM reclada_object.refresh_mv('uniFields');
    END IF;

    FOR _field_name IN 
        SELECT DISTINCT el
        FROM pg_catalog.jsonb_array_elements_text(
                (class_schema -> 'required') || coalesce((attrs -> 'required'),'[]'::jsonb)
            ) el
        WHERE NOT EXISTS (
            SELECT relname, ind_expr
            FROM (
                SELECT i.relname, pg_get_expr(ix.indexprs, ix.indrelid) AS ind_expr
                FROM pg_index ix
                JOIN pg_class i ON i.oid = ix.indexrelid 
                JOIN pg_class t ON t.oid = ix.indrelid 
                WHERE t.relname = 'object'
                AND ix.indexprs IS NOT NULL
            ) a
            WHERE
                length(ind_expr) - length(REPLACE(ind_expr,'->>',''))= 3
                AND strpos(ind_expr,el) > 0
        )
    LOOP
        EXECUTE E'CREATE INDEX ' || _field_name || '_index_ ON reclada.object USING BTREE (( attributes ->>''' || _field_name || ''')) WHERE attributes ->>''' || _field_name || ''' IS NOT NULL';
    END LOOP;

END;
$$ LANGUAGE PLPGSQL VOLATILE;

