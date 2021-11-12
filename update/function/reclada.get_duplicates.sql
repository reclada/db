/*
 * Function reclada.get_duplicates returns GUID, duplicate behavior, duplicate field.
 * Required parameters:
 *  _attrs      - attributes of object
 *  _class_uuid - class of object
 */

DROP FUNCTION IF EXISTS reclada.get_duplicates;
CREATE OR REPLACE FUNCTION reclada.get_duplicates(_attrs jsonb, _class_uuid uuid)
RETURNS TABLE (
    obj_guid        uuid,
    dup_behavior    dp_bhvr,
    dup_field       text) AS $$
    SELECT obj_id, dup_behavior, is_cascade, f1
        FROM reclada.v_active_object vao
        JOIN reclada.v_unifields_pivoted vup ON vao."class" = vup.class_uuid
        WHERE (vao.attrs ->> f1) || COALESCE((vao.attrs ->> f2),'') || COALESCE((vao.attrs ->> f3),'') || COALESCE((vao.attrs ->> f4),'') || COALESCE((vao.attrs ->> f5),'') || COALESCE((vao.attrs ->> f6),'') || COALESCE((vao.attrs ->> f7),'') || COALESCE((vao.attrs ->> f8),'')
            = (_attrs ->> f1) || COALESCE((_attrs ->> f2),'') || COALESCE((_attrs ->> f3),'') || COALESCE((_attrs ->> f4),'') || COALESCE((_attrs ->> f5),'') || COALESCE((_attrs ->> f6),'') || COALESCE((_attrs ->> f7),'') || COALESCE((_attrs ->> f8),'')
            AND vao."class" = _class_uuid
$$ LANGUAGE SQL VOLATILE;