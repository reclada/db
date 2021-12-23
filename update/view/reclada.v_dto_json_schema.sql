drop VIEW if EXISTS reclada.v_DTO_json_schema;
CREATE OR REPLACE VIEW reclada.v_DTO_json_schema
AS
    SELECT  obj.id            ,
            obj.obj_id        ,
            obj.attrs->>'function' as function,
            (obj.attrs->'schema') as schema,
            obj.revision_num  ,
            obj.status_caption,
            obj.revision      ,
            obj.created_time  ,
            obj.attrs         ,
            obj.status        ,
            obj.data          ,
            obj.parent_guid
	FROM reclada.v_active_object obj
   	WHERE class_name = 'DTOJsonSchema';


