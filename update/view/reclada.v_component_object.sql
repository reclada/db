drop VIEW if EXISTS reclada.v_component_object;
CREATE OR REPLACE VIEW reclada.v_component_object
AS
    SELECT  o.id,
            c.name component_name, 
            c.guid component_guid, 
            o.transaction_id,
            o.class_name, 
            o.obj_id,
            o.data obj_data,
            r.guid relationship_guid
        FROM reclada.v_component c
        JOIN reclada.v_relationship r
            ON r.parent_guid = c.guid
                AND 'data of reclada-component' = r.type
        JOIN reclada.v_active_object o
            ON o.obj_id = r.subject;
--select * from reclada.v_component_object
