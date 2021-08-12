-- version = 1
/*
	you can use "\i 'function/reclada_object.get_schema.sql'"
	to run text script of functions
*/

​\i 'function/public.try_cast_int.sql'

create table reclada.object_status
(
    id      bigint GENERATED ALWAYS AS IDENTITY primary KEY,
    caption text
);
insert into reclada.object_status(caption)
    select 'active';
insert into reclada.object_status(caption)
    select 'archive';

alter table reclada.object
	add id bigint GENERATED ALWAYS AS IDENTITY primary KEY,
	add obj_id       uuid   ,
	add revision     uuid   ,
	add obj_id_int   int    ,
	add	revision_int bigint ,
	add	class        text   ,
	add	status       int     DEFAULT 1,--active
	add	attrs        jsonb  ,
	add time_when    timestamp with time zone DEFAULT now(),
    add CONSTRAINT fk_status
      FOREIGN KEY(status) 
	  REFERENCES reclada.object_status(id);
	
update reclada.object 
	set obj_id_int = public.try_cast_int(data->>'id'),
	    class  = data->>'class',
	    revision_int  = (data->'revision')::bigint ,
	    status  = (data->'isDeleted')::boolean::int+1,
	    attrs  = data->'attrs';
​
update reclada.object 
	set obj_id = (data->>'id')::uuid
        WHERE obj_id_int is null;
​
update reclada.object 
	set status = 1
        WHERE status is null;
​

    
​
alter table reclada.object alter column data drop not null;
​
-- select * from reclada.object

