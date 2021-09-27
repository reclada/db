/*
example:
1) select reclada_object.get_transaction_id(
    '{"action":"new"}'
    ::jsonb);
2) select reclada_object.get_transaction_id(
    '{"GUID":"3748b1f7-b674-47ca-9ded-d011b16bbf7b"}'
    ::jsonb);
3) select reclada_object.get_transaction_id('{}'::jsonb);
    result: ERROR:  Parameter has to contain GUID or action. 
*/

DROP FUNCTION IF EXISTS reclada_object.get_transaction_id;
CREATE OR REPLACE FUNCTION reclada_object.get_transaction_id(_data jsonb)
RETURNS jsonb
LANGUAGE PLPGSQL VOLATILE
AS $$
DECLARE
    _action text;
    _res jsonb;
    _tran_id bigint;
    _guid uuid;
    _func_name text;
BEGIN
    _func_name := 'reclada_object.get_transaction_id';
    _action := _data ->> 'action';
    _guid := _data ->> 'GUID';

    if    _action = 'new' and _guid is null    
    then
        _tran_id := reclada.get_transaction_id();
    ELSIF _action is null  and _guid is not null 
    then
        select o.transaction_id 
            from reclada.v_object o
                where _guid = o.obj_id
        into _tran_id;
        if _tran_id is null 
        then
            perform reclada.raise_exception('GUID not found.',_func_name);
        end if;
    else 
        perform reclada.raise_exception('Parameter has to contain GUID or action.',_func_name);
    end if;

    RETURN format('{"transactionID":%s}',_tran_id):: jsonb;
END;
$$;