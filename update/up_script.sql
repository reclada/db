-- version = 32
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

-- remove revision from object
\i 'view/reclada.v_object.sql'

update reclada.object
set transaction_id = reclada.get_transaction_id()
	where transaction_id is null;

alter table reclada.object
    alter COLUMN transaction_id set not null;

-- improve for {"class": "609ed4a4-f73a-4c05-9057-57bd212ef8ff"} 
\i 'function/reclada_object.list.sql'

\i 'function/reclada_object.get_transaction_id.sql'
\i 'function/api.reclada_object_get_transaction_id.sql'
\i 'function/reclada_revision.create.sql'
\i 'function/reclada_object.update.sql'

CREATE INDEX transaction_id_index ON reclada.object (transaction_id);
