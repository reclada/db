/*
 * Function reclada_object.transaction_rollback marks transaction as rolled back 
 *      and undo objects from that transaction.
 * Required parameters:
 *  _transaction_id -   ID of rolled back transaction.
*/

DROP FUNCTION IF EXISTS reclada_object.transaction_rollback;
CREATE OR REPLACE FUNCTION reclada_object.transaction_rollback
(
    _transaction_id bigint
)
RETURNS void
LANGUAGE PLPGSQL VOLATILE
AS $body$
BEGIN
    INSERT INTO reclada.transaction_rollback (transaction_id)
        VALUES (_transaction_id)
    ON CONFLICT ON CONSTRAINT transaction_id
        DO NOTHING;
    PERFORM reclada_object.undo(id)
    FROM reclada.v_active_object
    WHERE transaction_id = _transaction_id;
END;
$body$;
