-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
DROP VIEW IF EXISTS reclada.v_parent_field;
DROP VIEW IF EXISTS reclada.v_class;
DROP VIEW IF EXISTS reclada.v_import_info;
DROP VIEW IF EXISTS reclada.v_revision;
DROP VIEW IF EXISTS reclada.v_task;
DROP VIEW IF EXISTS reclada.v_ui_active_object;
DROP VIEW IF EXISTS reclada.v_dto_json_schema;
DROP VIEW IF EXISTS reclada.v_component_object;
DROP VIEW IF EXISTS reclada.v_component;
DROP VIEW IF EXISTS reclada.v_relationship;
DROP VIEW IF EXISTS reclada.v_active_object;
DROP VIEW IF EXISTS reclada.v_object;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_class_lite;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_user;
DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_status;
DROP VIEW IF EXISTS reclada.v_object_display;

--{function/reclada_object.get_jsonschema_guid}


CREATE MATERIALIZED VIEW reclada.v_class_lite
AS
WITH RECURSIVE
objects_schemas AS (
    SELECT  obj.id,
            obj.GUID AS obj_id,
            obj.attributes->>'forClass' AS for_class,
            (attributes->>'version')::bigint AS version,
            obj.created_time,
            obj.attributes,
            obj.status
	    FROM reclada.object obj
   	    WHERE class = reclada_object.get_jsonschema_guid()
),
paths_to_default AS
(
    SELECT   ('{'||row_attrs_base.key||'}')::text[] AS path_head,
             row_attrs_base.value AS path_tail,
             o.obj_id
        FROM objects_schemas o
        CROSS JOIN LATERAL jsonb_each(o.attributes) row_attrs_base
        WHERE jsonb_typeof(row_attrs_base.value) = 'object'
            AND attributes::text LIKE '%default%'
    UNION ALL
    SELECT   p.path_head || row_attrs_rec.key AS path_head, -- {schema,properties,nested_1,nested_2,nested_3}
             row_attrs_rec.value AS path_tail, ---{"type": "integer", "default": 100}
             p.obj_id
       FROM paths_to_default p
       CROSS JOIN LATERAL jsonb_each(p.path_tail) row_attrs_rec
       WHERE jsonb_typeof(row_attrs_rec.value) = 'object'
),
tmp AS
(
    SELECT
            format('"%s":%s',
                  (t.path_head[array_position(t.path_head, 'properties') + 1 : ])::text, -- {schema,properties,nested_1,nested_2,nested_3} -> {nested_1,nested_2,nested_3}
                  t.path_tail->'default'
            )
             AS default_jsonb,
            t.obj_id
        FROM paths_to_default t
        WHERE t.path_tail->'default' IS NOT NULL
),
default_field AS
(
    SELECT   format('{%s}', string_agg(default_jsonb, ','))::jsonb AS default_value,
             obj_id
        FROM tmp
        GROUP BY obj_id
)
SELECT
        obj.id,
        obj.obj_id,
        obj.attributes->>'forClass' AS for_class,
        (attributes->>'version')::bigint AS version,
        obj.created_time,
        obj.attributes,
        obj.status,
        default_value
    FROM objects_schemas obj
        LEFT JOIN default_field def
        ON def.obj_id = obj.obj_id;

ANALYZE reclada.v_class_lite;


--{function/reclada_object.get_guid_for_class}

CREATE MATERIALIZED VIEW reclada.v_object_status
AS
    SELECT  obj.id            ,
            obj.GUID as obj_id,
            obj.attributes->>'caption' as caption,
            obj.created_time  ,
            obj.attributes as attrs
	FROM reclada.object obj
   	WHERE class in (select reclada_object.get_guid_for_class('ObjectStatus'));
--        and status = reclada_object.get_active_status_obj_id();
ANALYZE reclada.v_object_status;


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
ANALYZE reclada.v_user;



--{function/reclada_object.delete}
--{view/reclada.v_object_display}
--{function/reclada_object.need_flat}

--{view/reclada.v_object}
--{view/reclada.v_object_display}
--{view/reclada.v_active_object}
--{view/reclada.v_relationship}
--{view/reclada.v_component}
--{view/reclada.v_component_object}
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
                AND vc.status = reclada_object.get_active_status_obj_id()
            ) a
        ) b
;
ANALYZE reclada.v_object_unifields;

