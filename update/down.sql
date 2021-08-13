-- you you can use "--{function/reclada_object.get_schema}"
-- to add current version of object to downgrade script

--{function/public.try_cast_int}



update reclada.object o
    set data =
--select  
(
            '{"id":' || coalesce((o.obj_id_int)::text,('"'||o.obj_id||'"'):: text)  
            || coalesce(',"revision":'|| o.revision_int::text,'')
            || coalesce(',"class":"'  || o.class||'"' ,'')
            || coalesce(',"isDeleted":'|| (o.status-1)::boolean::text ,'')
            || coalesce(',"attrs":'|| o.attrs::text ,'')
            || '}'
        )::jsonb ;
    -- from reclada.object o
​
alter table reclada.object alter column data set not null;
​
drop view if EXISTS reclada.v_class;
drop view if EXISTS reclada.v_revision;
drop view if EXISTS reclada.v_object;

alter table reclada.object 
    drop column revision,
	drop column id      ,
	drop column obj_id  ,
	drop column	name    ,
	drop column	class   ,
	drop column	status  ,
	drop column	attrs   ,
	drop column created_time,
	drop column created_by;

--{view/reclada.v_object}
--{view/reclada.v_class}

drop table reclada.object_status;

