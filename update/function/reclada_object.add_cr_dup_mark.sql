/*
 * Function reclada_object.add_cr_dup_mark delete old duplication marks, add new mark.
 * Required parameters:
 *  _parent_guid        - current guid of mark object
 *  _transaction_id     - transaction id of object
 *  _dup_behavior        - behavior of mark
 */

DROP FUNCTION IF EXISTS reclada_object.add_cr_dup_mark;
CREATE OR REPLACE FUNCTION reclada_object.add_cr_dup_mark(_parent_guid uuid,  _transaction_id int8, _dup_behavior reclada.dp_bhvr)
RETURNS void AS $$
BEGIN
    DELETE FROM reclada_object.cr_dup_behavior
    WHERE transaction_id IN (
        SELECT transaction_id
        FROM (
            SELECT MAX(last_use) AS max_last_use,
                transaction_id
            FROM reclada_object.cr_dup_behavior
            WHERE dup_behavior = _dup_behavior
            GROUP BY transaction_id
        ) A
        WHERE max_last_use < current_timestamp - interval '1 day'
    );

    INSERT INTO reclada_object.cr_dup_behavior
        (parent_guid,  transaction_id, dup_behavior)
    VALUES
        (_parent_guid,  _transaction_id, _dup_behavior)
    ON CONFLICT (transaction_id, parent_guid)
        DO UPDATE 
        SET dup_behavior = _dup_behavior,
            last_use = current_timestamp;
END;
$$ LANGUAGE PLPGSQL VOLATILE;