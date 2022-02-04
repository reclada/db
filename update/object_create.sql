SELECT reclada_object.create('{
        "GUID": "db0bb665-6aa4-45d5-876c-173a7e921f94",
        "class": "Context",
        "attributes": {
            "Lambda": "#@#lname#@#",
            "Region": "#@#lregion#@#",
            "Environment": "#@#ename#@#"
        }    
    }'::jsonb);
select reclada_object.create('{
    "GUID": "db0873d1-786f-4d5d-b790-5c3b3cd29baf",
    "class": "Index",
    "attributes": {
        "name": "checksum_index_",
        "fields": ["(attributes ->> ''checksum''::text)"],
        "method": "hash",
        "wherePredicate": "((attributes ->> ''checksum''::text) IS NOT NULL)"
    }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db08d53b-c423-4e94-8b14-e73ebe98e991",
        "class": "Index",
        "attributes": {
            "name": "repository_index_",
            "fields": ["(attributes ->> ''repository''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''repository''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
    "GUID": "db05e253-7954-4610-b094-8f9925ea77b4",
    "class": "Index",
    "attributes": {
            "name": "commithash_index_",
            "fields": ["(attributes ->> ''commitHash''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''commitHash''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
    "GUID": "db02f980-cd5a-4c1a-9341-7a81713cd9d0",
    "class": "Index",
    "attributes": {
            "name": "fields_index_",
            "fields": ["(attributes ->> ''fields''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''fields''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0e400b-1da4-4823-bb80-15eb144a1639",
        "class": "Index",
        "attributes": {
                "name": "caption_index_",
                "fields": ["(attributes ->> ''caption''::text)"],
                "method": "btree",
                "wherePredicate": "((attributes ->> ''caption''::text) IS NOT NULL)"
            }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db09fafb-91b1-4fe6-8e5c-1cd2d7d9225a",
        "class": "Index",
        "attributes": {
            "name": "type_index",
            "fields": ["(attributes ->> ''type''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''type''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0118e5-ea34-45dc-b72c-f16f6a628ddb",
        "class": "Index",
        "attributes": {
            "name": "schema_index_",
            "fields": ["(attributes ->> ''schema''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''schema''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db07c919-5bc0-4fec-961c-f558401d3e71",
        "class": "Index",
        "attributes": {
            "name": "forclass_index_",
            "fields": ["(attributes ->> ''forclass''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''forclass''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0184b8-556e-4f57-af12-d84066adbe31",
        "class": "Index",
        "attributes": {
            "name": "revision_index",
            "fields": ["(attributes ->> ''revision''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''revision''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0e22c0-e0d7-4b11-bf25-367a8fbdef83",
        "class": "Index",
        "attributes": {
            "name": "subject_index_",
            "fields": ["(attributes ->> ''subject''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''subject''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db05c9c7-17ce-4b36-89d7-81b0ddd26a6a",
        "class": "Index",
        "attributes": {
            "name": "class_index_",
            "fields": ["(attributes ->> ''class''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''class''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0a88c1-ac00-42e5-9caa-6007a1c948c6",
        "class": "Index",
            "attributes": {
            "name": "name_index_",
            "fields": ["(attributes ->> ''name''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''name''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0fdc46-6479-4d20-bd21-a6330905e45b",
        "class": "Index",
        "attributes": {
            "name": "event_index_",
            "fields": ["(attributes ->> ''event''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''event''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db02b45a-acfd-4448-a51a-8e7dc35bf3af",
        "class": "Index",
        "attributes": {
            "name": "function_index_",
            "fields": ["(attributes ->> ''function''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''function''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db0b797a-b287-4282-b0f8-d985c7a439f4",
        "class": "Index",
        "attributes": {
            "name": "login_index_",
            "fields": ["(attributes ->> ''login''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''login''::text) IS NOT NULL)"
        }    
    }'::jsonb);
select reclada_object.create('{
        "GUID": "db03c715-c0f9-43c3-940a-803aafa513e0",
        "class": "Index",
        "attributes": {
            "name": "object_index_",
            "fields": ["(attributes ->> ''object''::text)"],
            "method": "btree",
            "wherePredicate": "((attributes ->> ''object''::text) IS NOT NULL)"
        }    
    }'::jsonb);
