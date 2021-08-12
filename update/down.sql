-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

alter table dev.test1 drop column id;

--{function/public.try_cast_int}