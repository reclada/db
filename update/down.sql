-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

drop table reclada.unique_object_reclada_object;
drop table reclada.unique_object;
drop table reclada.field;

--{function/reclada_object.create}
--{function/reclada_object.get_schema}
--{view/reclada.v_ui_active_object}
--{function/reclada_object.update}
--{function/reclada_object.list}
--{function/reclada.update_unique_object}
--{function/reclada_object.get_active_status_obj_id}
--{function/reclada_object.get_archive_status_obj_id}
--{view/reclada.get_children}
--{view/reclada.v_filter_mapping}

DROP INDEX relationship_type_subject_object_index;

DROP INDEX parent_guid_index;
CREATE INDEX parent_guid_index ON reclada.object USING btree (parent_guid);

DROP INDEX document_fileguid_index;
CREATE INDEX document_fileguid_index ON reclada.object USING btree (attributes ->> 'fileGUID');

CREATE INDEX file_uri_index ON reclada.object USING btree (attributes ->> 'uri');

DROP INDEX job_status_index;
CREATE INDEX job_status_index ON reclada.object USING btree (attributes ->> 'status');

DROP INDEX revision_index;
CREATE INDEX revision_index ON reclada.object USING btree (attributes ->> 'revision');

DROP INDEX runner_type_index;
CREATE INDEX runner_type_index ON reclada.object USING btree (attributes ->> 'type');

DROP INDEX guid_index;
CREATE INDEX guid_index ON reclada.object USING btree (guid);

DROP INDEX checksum_index_;
CREATE INDEX checksum_index_ ON reclada.object USING hash (attributes ->> 'checksum');

DROP INDEX uri_index_;
CREATE INDEX uri_index_ ON reclada.object USING hash (attributes ->> 'uri');