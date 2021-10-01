DROP FUNCTION IF EXISTS api.reclada_object_get_transaction_id;
CREATE OR REPLACE FUNCTION api.reclada_object_get_transaction_id(data JSONB)
RETURNS JSONB AS $$
BEGIN
    return reclada_object.get_transaction_id(data);
END;
$$ LANGUAGE PLPGSQL VOLATILE;
