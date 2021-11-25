-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script



drop table reclada.draft;

--{function/api.reclada_object_create}
--{function/api.reclada_object_list}
--{function/api.reclada_object_delete}
--{function/api.reclada_object_update}

--{function/reclada_object.create}
--{function/reclada_object.datasource_insert}
--{function/reclada_object.list}
--{function/reclada_object.get_query_condition_filter}
--{function/reclada_object.parse_filter}

--{function/reclada.raise_exception}
--{view/reclada.v_filter_avaliable_operator}

-- delete from reclada.object 
--     where guid in (select reclada_object.get_GUID_for_class('Asset'));
-- 
-- delete from reclada.object 
--     where guid in (select reclada_object.get_GUID_for_class('DBAsset'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,object,minLength}'
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));

UPDATE reclada.OBJECT
SET ATTRIBUTES = ATTRIBUTES #- '{schema,properties,subject,minLength}'
WHERE guid IN(SELECT reclada_object.get_GUID_for_class('Relationship'));

DROP OPERATOR IF EXISTS reclada.##(boolean, boolean);
CREATE OPERATOR reclada.# (
    FUNCTION = reclada.xor,
    LEFTARG = boolean,
    RIGHTARG = boolean
);

insert into reclada.object(status,attributes,created_by,class,guid, transaction_id)
      select /*64,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Object display", "classGUID": "74c22b58-ecec-4666-90b1-23e5bb04d98e"}':: jsonb,  /*,63 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    'd5f8b72e-c4cc-4d60-97e3-8fdcd7e5969e'::uuid, reclada.get_transaction_id()
union select /*65,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Data row", "classGUID": "7643b601-43c2-4125-831a-539b9e7418ec"}'      :: jsonb,  /*,64 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    '4dfb7582-e919-42a0-968a-da69c5efe93c'::uuid, reclada.get_transaction_id()
union select /*66,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Text block", "classGUID": "9ed31858-a681-49fb-9e64-250b1afaf691"}'    :: jsonb,  /*,65 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    '4e445a19-3724-4c82-b4ea-81c93e877d7b'::uuid, reclada.get_transaction_id()
union select /*67,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Message", "classGUID": "54f657db-bc6a-4a37-8fb6-8566aee49b33"}'       :: jsonb,  /*,66 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    'ea949420-1194-4edd-8dca-929fb94e2e6b'::uuid, reclada.get_transaction_id()
union select /*68,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Page", "classGUID": "3ed1c180-a508-4180-9281-2f9b9a9cd477"}'          :: jsonb,  /*,67 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    '2b7b086e-70db-4b9d-9666-6c2324eeb5c4'::uuid, reclada.get_transaction_id()
union select /*69,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Document", "classGUID": "85d32073-4a00-4df7-9def-7de8d90b77e0"}'      :: jsonb,  /*,68 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    'bcd07282-612b-4255-89e5-44d4b824e6ea'::uuid, reclada.get_transaction_id()
union select /*70,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Json schema", "classGUID": "5362d59b-82a1-4c7c-8ec3-07c256009fb0"}'   :: jsonb,  /*,69 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    'fafe4139-cfbc-46f1-8686-4ad27b061c4c'::uuid, reclada.get_transaction_id()
union select /*71,*/ '3748b1f7-b674-47ca-9ded-d011b16bbf7b'::uuid, '{"caption": "Job", "classGUID": "75a8fd8b-f709-445c-a551-e8454c0ef179"}'           :: jsonb,  /*,70 ,'2021-11-17 14:11:31.38773+00',*/ '16d789c1-1b4e-4815-b70c-4ef060e90884'::uuid,    '74c22b58-ecec-4666-90b1-23e5bb04d98e'::uuid,    '351a69d9-9368-49c5-991f-a353dde4b739'::uuid, reclada.get_transaction_id()

