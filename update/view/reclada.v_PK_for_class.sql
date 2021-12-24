drop VIEW if EXISTS reclada.v_pk_for_class;
CREATE OR REPLACE VIEW reclada.v_pk_for_class
AS
    SELECT  obj.obj_id    as guid,
            obj.for_class,
            pk.pk
        FROM reclada.v_class_lite obj
        JOIN
        (
            select  'File' as class_name,
                    'uri'  as pk
            UNION 
            select  'DTOJsonSchema',
                    'function'
        ) pk
            on pk.class_name = obj.for_class;
    

