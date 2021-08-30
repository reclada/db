-- version = 8
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

DROP TRIGGER IF EXISTS datasource_insert_trigger ON reclada.object;
CREATE TRIGGER datasource_insert_trigger
  BEFORE INSERT
  ON reclada.object FOR EACH ROW
  EXECUTE PROCEDURE reclada.datasource_insert_trigger_fnc();

/*
    if we use AFTER trigger 
    code from reclada_object.create:
        with inserted as 
        (
            INSERT INTO reclada.object(class,attributes)
                select class, attrs
                    RETURNING obj_id
        ) 
        insert into tmp(id)
            select obj_id 
                from inserted;
    twice returns obj_id for object which created from trigger (Job).
    
    As result query:
        SELECT reclada_object.create('{"id": "", "class": "File", 
							 	"attrs":{
							 		"name": "SCkyqZSNmCFlWxPNSHWl", 
								 	"checksum": "", 
								 	"mimeType": "application/pdf", 
							 		"uri": "s3://test-reclada-bucket/inbox/SCkyqZSNmCFlWxPNSHWl"
							 }
							 }', null);
    selects only Job object.
*/