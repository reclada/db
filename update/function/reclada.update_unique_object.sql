

DROP FUNCTION IF EXISTS reclada.update_unique_object;
CREATE OR REPLACE FUNCTION reclada.update_unique_object
(
    guid_list uuid[],
    recalc_all bool = false
)
RETURNS bool AS $$
BEGIN
    IF array_length(guid_list,1) > 0 OR recalc_all THEN
        WITH obj_unique_fields AS MATERIALIZED(
            SELECT  vao.id, b.f_path, b.f_type 
            FROM reclada.v_active_object vao 
            CROSS JOIN reclada_object.explode_jsonb(vao.attrs,'attributes' ) b
            WHERE  vao.class_name NOT IN ('ObjectDisplay','jsonschema')
            AND (recalc_all OR obj_id = ANY (guid_list))
        ),
        f AS (
            INSERT INTO reclada.field(path, json_type)
                SELECT DISTINCT ouf.f_path, ouf.f_type
                FROM obj_unique_fields ouf
            ON CONFLICT(path, json_type)
            DO NOTHING
            RETURNING id, path, json_type
        ),
        all_fields AS (
            SELECT id, path, json_type
            FROM f
            UNION
            SELECT id, path, json_type
            FROM reclada.field
        ),
        objects_with_fields AS (
            SELECT array_agg(f.id ORDER BY f.id) AS id_field, ouf.id
            FROM obj_unique_fields ouf
            JOIN all_fields f ON ouf.f_path = f.PATH AND ouf.f_type = f.json_type
            GROUP BY ouf.id
        ),
        uo AS (
            INSERT INTO reclada.unique_object(id_field)
                SELECT DISTINCT id_field
                FROM objects_with_fields
            ON CONFLICT(id_field)
            DO NOTHING
            RETURNING id,id_field
        ),
        all_uo AS (
            SELECT id, id_field
            FROM uo
            UNION
            SELECT id, id_field
            FROM reclada.unique_object uo
        )
        INSERT INTO reclada.unique_object_reclada_object (id_unique_object, id_reclada_object)
            SELECT uo.id, owf.id
            FROM objects_with_fields owf
            JOIN all_uo uo ON owf.id_field=uo.id_field
        ON CONFLICT (id_unique_object, id_reclada_object)
        DO NOTHING;

        RETURN true;
    ELSE
        RETURN false;
    END IF;
    
END;
$$ LANGUAGE PLPGSQL VOLATILE;