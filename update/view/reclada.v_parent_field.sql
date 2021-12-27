DROP VIEW IF EXISTS reclada.v_parent_field;
CREATE OR REPLACE VIEW reclada.v_parent_field AS
    SELECT
        for_class,
        obj_id as class_uuid,
        attrs->>'parentField' AS parent_field
    FROM reclada.v_class
    WHERE attrs->>'parentField' IS NOT NULL;