-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

alter table dev.component drop column parent_component_name;
--{function/dev.finish_install_component}
--{function/dev.begin_install_component}

--{view/reclada.v_ui_active_object}
--{view/reclada.v_component_object}
--{function/reclada_object.create_job}
--{function/api.storage_generate_presigned_post}

update reclada.object u
    set transaction_id = m.tran_id
    from (
        select  (data->>'id')::bigint as id  ,
                (data->>'tran_id')::bigint tran_id
            from dev.meta_data
    ) m
    where m.id = u.id;

drop table dev.meta_data;

--{function/dev.begin_install_component}
--{function/dev.finish_install_component}
--{function/dev.downgrade_component}
--{function/reclada_object.create_relationship}
--{function/reclada_object.create_subclass}
--{function/reclada_object.update}

--{function/dev.downgrade_version}
--{view/reclada.v_object_display}
drop VIEW reclada.v_component_object;
--{view/reclada.v_component}
--{view/reclada.v_component_object}

    delete from reclada.object 
        where guid in 
        (
            SELECT relationship_guid 
                FROM reclada.v_component_object 
                    where class_name in (   'jsonschema', 
                                            'DataSet',
                                            'User',
                                            'DTOJsonSchema',
                                            'ObjectDisplay',
                                            'Message'
                                        )
                        and component_name = 'db'
        );

    -- delete from reclada.object 
    --     where class in (select reclada_object.get_GUID_for_class('Index'));


--{function/reclada_object.create}
--{function/reclada_object.merge}
--{function/reclada_object.list}
--{view/reclada.v_ui_active_object}

DROP MATERIALIZED VIEW IF EXISTS reclada.v_object_unifields;
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
ANALYZE reclada.v_object_unifields;

ALTER SEQUENCE IF EXISTS reclada.object_id_seq CACHE 1;
