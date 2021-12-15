-- version = 42
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'function/reclada_object.datasource_insert.sql'
\i 'view/reclada.v_task.sql'
\i 'view/reclada.v_pk_for_class.sql'


SELECT reclada_object.create_subclass('{
    "class": "Task",
    "attributes": {
        "newClass": "PipelineLite",
        "properties": {
            "tasks": {
                "items": {
                    "pattern": "[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89aAbB][a-f0-9]{3}-[a-f0-9]{12}",
                    "type": "string"
                },
                "type": "array",
                "minItems": 1
            }
        },
        "required": ["tasks"]
    }
}'::jsonb);

select reclada_object.create('{
    "GUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "class":"PipelineLite",
    "attributes":{
        "command":"",
        "type":"pipelineLite",
        "tasks":[
                    "cc7b41e6-4d57-4e6f-9d10-6da0d5a4c39e",
                    "618b967b-f2ff-4f3b-8889-b63eb6b73b6e",
                    "678bbbcc-a6db-425b-b9cd-bdb302c8d290",
                    "638c7f45-ad21-4b59-a89d-5853aa9ad859",
                    "2d6b0afc-fdf0-4b54-8a67-704da585196e",
                    "ff3d88e2-1dd9-43b3-873f-75e4dc3c0629",
                    "83fbb176-adb7-4da0-bd1f-4ce4aba1b87a",
                    "27de6e85-1749-4946-8a53-4316321fc1e8",
                    "4478768c-0d01-4ad9-9a10-2bef4d4b8007"'/*,
                    "35e5bce3-6578-41ae-a7e2-d20b9a19ba00",
                    "b68040ff-2f37-42da-b865-8edf589acdaa"*/'
        ]
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"cc7b41e6-4d57-4e6f-9d10-6da0d5a4c39e",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage0.sh",
        "type":"PipelineLite step 1"
    }
}'::jsonb);
select reclada_object.create('{
    "class":"Task",
    "GUID":"618b967b-f2ff-4f3b-8889-b63eb6b73b6e",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage1.sh",
        "type":"PipelineLite step 2"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"678bbbcc-a6db-425b-b9cd-bdb302c8d290",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage2.sh",
        "type":"PipelineLite step 3"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"638c7f45-ad21-4b59-a89d-5853aa9ad859",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage3.sh",
        "type":"PipelineLite step 4"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"2d6b0afc-fdf0-4b54-8a67-704da585196e",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage4.sh",
        "type":"PipelineLite step 5"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"ff3d88e2-1dd9-43b3-873f-75e4dc3c0629",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage5.sh",
        "type":"PipelineLite step 6"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"83fbb176-adb7-4da0-bd1f-4ce4aba1b87a",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage6.sh",
        "type":"PipelineLite step 7"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"27de6e85-1749-4946-8a53-4316321fc1e8",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage7.sh",
        "type":"PipelineLite step 8"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"4478768c-0d01-4ad9-9a10-2bef4d4b8007",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"./stage8.sh",
        "type":"PipelineLite step 9"
    }
}'::jsonb);
/*
select reclada_object.create('{
    "class":"Task",
    "GUID":"35e5bce3-6578-41ae-a7e2-d20b9a19ba00",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"",
        "type":"PipelineLite step 10"
    }
}'::jsonb);

select reclada_object.create('{
    "class":"Task",
    "GUID":"b68040ff-2f37-42da-b865-8edf589acdaa",
    "parentGUID":"57ca1d46-146b-4bbb-8f4d-b620c4e62d93",
    "attributes":{
        "command":"",
        "type":"PipelineLite step 11"
    }
}'::jsonb);

*/