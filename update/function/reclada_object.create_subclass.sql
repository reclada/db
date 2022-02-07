/*
 * Function reclada_object.create_subclass creates subclass.
 * A jsonb object with the following parameters is required.
 * Required parameters:
 *  _class_list - the name of parent _class_list
 *  attributes - the attributes of objects of the _class_list. The field contains:
 *      forClass - the name of _class_list to create
 *      schema - the schema for the _class_list
 */

DROP FUNCTION IF EXISTS reclada_object.create_subclass;
CREATE OR REPLACE FUNCTION reclada_object.create_subclass(_data jsonb)
RETURNS jsonb AS $$
DECLARE
    _class_list     jsonb;
    _res            jsonb = '{}'::jsonb;
    _class          text;
    _properties     jsonb;
    _p_properties   jsonb;
    _required       jsonb;
    _p_required     jsonb;
    _parent_list    jsonb := '[]';
    _new_class      text;
    attrs           jsonb;
    class_schema    jsonb;
    _version        integer;
    class_guid      uuid;
    _uniFields      jsonb;
    _idx_name       text;
    _f_list         text;
    _field          text;
    _f_name         text = 'reclada_object.create_subclass';
    _partial_clause text;
    _field_name     text;
    _create_obj     jsonb;
    _component_guid uuid;
    _obj_guid       uuid;
    _c              int;
BEGIN

    _class_list := _data->'class';
    IF (_class_list IS NULL) THEN
        perform reclada.raise_exception('The reclada object class is not specified',_f_name);
    END IF;

    _obj_guid := coalesce((_data->>'GUID')::uuid,public.uuid_generate_v4());

    IF (jsonb_typeof(_class_list) != 'array') THEN
        _class_list := '[]'::jsonb || _class_list;
    END IF;

    attrs := _data->'attributes';
    IF (attrs IS NULL) THEN
        perform reclada.raise_exception('The reclada object must have attributes',_f_name);
    END IF;

    _new_class = attrs->>'newClass';
    _properties := coalesce(attrs -> 'properties','{}'::jsonb);
    _required   := coalesce(attrs -> 'required'  ,'[]'::jsonb);

    SELECT guid 
        FROM dev.component 
        INTO _component_guid;

    if _component_guid is not null then
        update dev.component_object
            set status = 'ok'
            where status = 'need to check'
                and _new_class  = data #>> '{attributes,forClass}'
                and _properties = data #>  '{attributes,schema,properties}'
                and _required   = data #>  '{attributes,schema,required}'
                and jsonb_array_length(_class_list) = jsonb_array_length(data #> '{attributes,parentList}');

        GET DIAGNOSTICS _c := ROW_COUNT;
        if _c > 1 then
            perform reclada.raise_exception('can''t mach component objects',_f_name);
        elsif _c = 1 then
            return _res;
        end if;

        -- upgrade jsonschema
        with u as (
            update dev.component_object
                set status = 'delete'
                where status = 'need to check'
                    and _new_class  = data #>> '{attributes,forClass}'
                RETURNING 1 as v
        )
        insert into dev.component_object( data, status  )
            select _data, 'create_subclass'
                from u;

        GET DIAGNOSTICS _c := ROW_COUNT;
        if _c > 1 then
            perform reclada.raise_exception('can''t mach component objects',_f_name);
        elsif _c = 1 then
            return _res;
        end if;

        insert into dev.component_object( data, status  )
                select _data, 'create_subclass';
            return _res;
    end if;

    FOR _class IN SELECT jsonb_array_elements_text(_class_list)
    LOOP

        SELECT reclada_object.get_schema(_class) 
            INTO class_schema;

        IF (class_schema IS NULL) THEN
            perform reclada.raise_exception('No json schema available for ' || _class, _f_name);
        END IF;
        
        SELECT class_schema->>'GUID'
            INTO class_guid;
        
        _parent_list := _parent_list || to_jsonb(class_guid);

    END LOOP;
   
    SELECT max(version) + 1
    FROM reclada.v_class_lite v
    WHERE v.for_class = _new_class
        INTO _version;

    _version := coalesce(_version,1);

    _create_obj := format('{
        "class": "jsonschema",
        "GUID": "%s",
        "attributes": {
            "forClass": "%s",
            "version": "%s",
            "schema": {
                "type": "object",
                "properties": %s,
                "required": %s
            },
            "parentList":%s
        }
    }',
    _obj_guid::text,
    _new_class,
    _version,
    _properties,
    _required,
    _parent_list
    )::jsonb;
    IF ( jsonb_typeof(attrs->'dupChecking') = 'array' ) THEN
        _create_obj := jsonb_set(_create_obj, '{attributes,dupChecking}',attrs->'dupChecking');
        IF ( jsonb_typeof(attrs->'dupBehavior') = 'string' ) THEN
            _create_obj := jsonb_set(_create_obj, '{attributes,dupBehavior}',attrs->'dupBehavior');
        END IF;
        IF ( jsonb_typeof(attrs->'isCascade') = 'boolean' ) THEN
            _create_obj := jsonb_set(_create_obj, '{attributes,isCascade}',attrs->'isCascade');
        END IF;
        IF ( jsonb_typeof(attrs->'copyField') = 'string' ) THEN
            _create_obj := jsonb_set(_create_obj, '{attributes,copyField}',attrs->'copyField');
        END IF;
    END IF;
    IF ( jsonb_typeof(attrs->'parentField') = 'string' ) THEN
        _create_obj := jsonb_set(_create_obj, '{attributes,parentField}',attrs->'parentField');
    END IF;
    select reclada_object.create(_create_obj)
        into _res;

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
                    SELECT jsonb_array_elements_text (_uniFields) f
                ) a
                    INTO _idx_name, _f_list, _partial_clause;
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
    return _res;
END;
$$ LANGUAGE PLPGSQL VOLATILE;

