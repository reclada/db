-- version = 35
/*
    you can use "\i 'function/reclada_object.get_schema.sql'"
    to run text script of functions
*/

\i 'view/reclada.v_PK_for_class.sql'
\i 'function/reclada.get_transaction_id_for_import.sql'
\i 'function/reclada.rollback_import.sql'

/*
    tests:
        SELECT  guid,
                for_class,
                pk 
            FROM reclada.v_pk_for_class;
    --x3
    select reclada_object.create('
    {
        "class":"File",
        "attributes":{
            "uri": "123",
            "name": "123",
            "tags": [],
            "checksum": "123",
            "mimeType": "pdf"
        }
    }');

*/
