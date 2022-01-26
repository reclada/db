drop VIEW if EXISTS reclada.v_filter_mapping;
CREATE OR REPLACE VIEW reclada.v_filter_mapping
AS
    SELECT '{class}' AS pattern     , 'class_name' AS repl
    UNION SELECT  '{status}'        , 'status_caption' 
    UNION SELECT  '{GUID}'          , 'obj_id' 
    UNION SELECT  '{transactionID}' , 'transaction_id' 
    UNION SELECT  '{createdTime}'   , 'created_time' 
    UNION SELECT  '{createdBy}'     , 'created_by' 
    UNION SELECT  '{classGUID}'     , 'class' 
    UNION SELECT  '{parentGUID}'    , 'parent_guid' 
;
