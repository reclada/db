/*
 * Function reclada_object.undo archive current revision
 *      and activate previous revision when possible.
 * Required parameters:
 *  _id -   ID of object to undo.
*/

DROP FUNCTION IF EXISTS reclada_object.undo;
CREATE OR REPLACE FUNCTION reclada_object.undo
(
    _id bigint
)
RETURNS void
LANGUAGE PLPGSQL VOLATILE
AS $body$
DECLARE
    _prev_id    bigint;
BEGIN
    SELECT vo.id
    FROM reclada.v_active_object vao
    JOIN reclada.v_object vo ON vao.obj_id=vo.obj_id AND vao.revision = vo.revision + 1
    WHERE vao.id = _id AND vao.revision IS NOT NULL
        INTO _prev_id;
    UPDATE reclada.object
    SET status = reclada.get_archive_status_obj_id()
    WHERE id = _id;
    UPDATE reclada.object
    SET status = reclada.get_active_status_obj_id()
    WHERE id = _prev_id;
END;
$body$;
