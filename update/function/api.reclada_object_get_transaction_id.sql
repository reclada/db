drop FUNCTION if exists api.reclada_object_get_transaction_id;
CREATE OR REPLACE FUNCTION api.reclada_object_get_transaction_id(data JSONB)
RETURNS JSONB AS $$
DECLARE
    _action text;
    _res jsonb;
    _guid text;
BEGIN
    return reclada_object.get_transaction_id(data);
END;
$$ LANGUAGE PLPGSQL VOLATILE;
