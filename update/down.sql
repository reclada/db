-- you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

select reclada.raise_exception('downgrade is not allowed');