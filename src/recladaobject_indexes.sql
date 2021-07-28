DROP INDEX IF EXISTS reclada.id_index;
CREATE INDEX id_index ON reclada.object ((data->'id'));

DROP INDEX IF EXISTS reclada.class_index;
CREATE INDEX class_index ON reclada.object ((data->'class'));

DROP INDEX IF EXISTS reclada.revision_index;
CREATE INDEX revision_index ON reclada.object ((data->'revision'));

DROP INDEX IF EXISTS reclada.is_deleted_index;
CREATE INDEX is_deleted_index ON reclada.object ((data->'isDeleted'));

DROP INDEX IF EXISTS reclada.job_status_index;
CREATE INDEX job_status_index ON reclada.object ((data->'attrs'->'status'))
WHERE (data->>'class' = 'Job');

DROP INDEX IF EXISTS reclada.runner_status_index;
CREATE INDEX runner_status_index ON reclada.object ((data->'attrs'->'status'))
WHERE (data->>'class' = 'Runner');

DROP INDEX IF EXISTS reclada.runner_type_index;
CREATE INDEX runner_type_index ON reclada.object ((data->'attrs'->'type'))
WHERE (data->>'class' = 'Runner');
