-- version = 35
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'view/reclada.v_PK_for_class.sql'
\i 'function/reclada.get_transaction_id_for_import.sql'
\i 'function/reclada.rollback_import.sql'

\i 'function/reclada_user.is_allowed.sql'
\i 'function/api.reclada_object_create.sql'
\i 'function/api.reclada_object_delete.sql'
\i 'function/api.reclada_object_get_transaction_id.sql'
\i 'function/api.reclada_object_list.sql'
\i 'function/api.reclada_object_list_add.sql'
\i 'function/api.reclada_object_list_drop.sql'
\i 'function/api.reclada_object_list_related.sql'
\i 'function/api.reclada_object_update.sql'
\i 'function/api.storage_generate_presigned_get.sql'
\i 'function/api.storage_generate_presigned_post.sql'
\i 'function/reclada_object.list.sql'

SELECT reclada_object.create_subclass('{
    "class": "RecladaObject",
    "attributes": {
        "newClass": "Document",
        "properties": {
            "name": {"type": "string"},
            "fileGUID": {"type": "string"}
        },
        "required": ["name", "fileGUID"]
    }
}'::jsonb);

SELECT reclada_object.create_subclass('{
    "class": "DataSource",
    "attributes": {
        "newClass": "File",
        "properties": {
            "checksum": {"type": "string"},
            "mimeType": {"type": "string"},
            "uri": {"type": "string"}
        },
        "required": ["checksum", "mimeType", "uri"]
    }
}'::jsonb);

CREATE INDEX IF NOT EXISTS revision_index ON reclada.object ((attributes->>'revision'));
CREATE INDEX IF NOT EXISTS job_status_index ON reclada.object ((attributes->>'status'));
CREATE INDEX IF NOT EXISTS runner_type_index  ON reclada.object ((attributes->>'type'));
CREATE INDEX IF NOT EXISTS file_uri_index  ON reclada.object ((attributes->>'uri'));
CREATE INDEX IF NOT EXISTS document_fileGUID_index  ON reclada.object ((attributes->>'fileGUID'));