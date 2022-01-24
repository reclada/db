-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script


drop table reclada.unique_object_reclada_object;
drop table reclada.unique_object;
drop table reclada.field;

--{function/reclada_object.create}
--{function/reclada_object.get_schema}
--{view/reclada.v_ui_active_object}
--{function/reclada_object.update}
--{function/reclada_object.list}
--{function/reclada.update_unique_object}
--{function/reclada.random_string}
--{function/api.reclada_object_list}
--{view/reclada.v_filter_mapping}


--------------default----------------
UPDATE reclada.object
SET attributes = '{
    "schema": {
        "id": "expr",
        "type": "object",
        "required": [
          "value",
          "operator"
        ],
        "properties": {
          "value": {
            "type": "array",
            "items": {
              "anyOf": [
                {
                  "type": "string"
                },
                {
                  "type": "null"
                },
                {
                  "type": "number"
                },
                {
                  "$ref": "expr"
                },
                {
                  "type": "array",
                  "items": {
                    "anyOf": [
                      {
                        "type": "string"
                      },
                      {
                        "type": "number"
                      }
                    ]
                  }
                }
              ]
            },
            "minItems": 1
          },
          "operator": {
            "type": "string"
          }
        }
      },
    "function": "reclada_object.get_query_condition_filter"
}'::jsonb
WHERE attributes->>'function' = 'reclada_object.get_query_condition_filter'
AND class IN (SELECT reclada_object.get_guid_for_class('DTOJsonSchema'));


UPDATE reclada.object
SET attributes = attributes #- '{schema, properties, disable}'
WHERE class IN (SELECT reclada_object.get_guid_for_class('jsonschema'))
AND attributes->>'forClass' != 'ObjectDisplay'
AND attributes->>'forClass' != 'jsonschema';


--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.create_subclass}
--{view/reclada.v_filter_available_operator}

DROP VIEW IF EXISTS reclada.v_unifields_pivoted;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
DROP VIEW IF EXISTS reclada.v_parent_field;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_task;
DROP VIEW IF EXISTS reclada.v_ui_active_object;
DROP VIEW IF EXISTS reclada.v_dto_json_schema;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_user;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_status;
DROP VIEW IF EXISTS reclada.v_object_display;

--{function/reclada_object.get_jsonschema_guid}

CREATE MATERIALIZED VIEW reclada.v_class_lite
AS
    SELECT  obj.id,
            obj.GUID as obj_id,
            obj.attributes->>'forClass' as for_class,
            (attributes->>'version')::bigint as version,
            obj.created_time,
            obj.attributes,
            obj.status
	FROM reclada.object obj
   	WHERE obj.class = reclada_object.get_jsonschema_GUID();

--{function/reclada_object.get_guid_for_class}
--{function/reclada_object.delete}
--{view/reclada.v_object_display}
--{function/reclada_object.need_flat}

CREATE MATERIALIZED VIEW reclada.v_object_status
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'caption' as caption,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class in (select reclada_object.get_guid_for_class('ObjectStatus'));

CREATE MATERIALIZED VIEW reclada.v_user
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'login' as login,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class in (select reclada_object.get_guid_for_class('User'))
        and status = reclada_object.get_active_status_obj_id();

--{view/reclada.v_object}
--{view/reclada.v_active_object}
--{view/reclada.v_dto_json_schema}
--{view/reclada.v_ui_active_object}
--{view/reclada.v_task}
--{view/reclada.v_revision}
--{view/reclada.v_import_info}
--{view/reclada.v_class}
--{view/reclada.v_parent_field}

CREATE MATERIALIZED VIEW reclada.v_object_unifields
AS
    SELECT
        for_class,
        class_uuid,
        CAST (dup_behavior AS reclada.dp_bhvr) AS dup_behavior,
        is_cascade,
        is_mandatory,
        uf as unifield,
        uni_number,
        row_number() OVER (PARTITION BY for_class,uni_number ORDER BY uf) AS field_number,
        copy_field
    FROM
        (
        SELECT
            for_class,
            obj_id                                      AS class_uuid,
            dup_behavior,
            is_cascade::boolean                         AS is_cascade,
            (dc->>'isMandatory')::boolean               AS is_mandatory,
            jsonb_array_elements_text(dc->'uniFields')  AS uf,
            dc->'uniFields'::text                       AS field_list,
            row_number() OVER ( PARTITION BY for_class ORDER BY dc->'uniFields'::text) AS uni_number,
            copy_field
        FROM
            (
            SELECT
                for_class,
                attributes->>'dupBehavior'           AS dup_behavior,
                (attributes->>'isCascade')           AS is_cascade,
                jsonb_array_elements( attributes ->'dupChecking') AS dc,
                obj_id,
                attributes->>'copyField' as copy_field
            FROM
                reclada.v_class_lite vc
            WHERE
                attributes ->'dupChecking' is not null
            ) a
        ) b
;

--{view/reclada.v_unifields_pivoted}






