drop VIEW if EXISTS reclada.v_default_display;
CREATE OR REPLACE VIEW reclada.v_default_display
AS
    SELECT       'string' as json_type  , '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}' as template
    UNION SELECT 'number'               , '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'
    UNION SELECT 'boolean'              , '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'
    UNION SELECT 'ObjectDisplay'        , 
                    '{
                        "classGUID": null,
                        "caption": "#@#classname#@#",
                        "table": {
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        },
                        "card":{
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        },
                        "preview":{
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        },
                        "list":{
                            "{status}:string":{
                                "caption": "Status",
                                "width": 250,
                                "displayCSS": "status"
                            },
                            "{createdTime}:string":{
                                "caption": "Created time",
                                "width": 250,
                                "displayCSS": "createdTime"
                            },
                            "{transactionID}:number":{
                                "caption": "Transaction",
                                "width": 250,
                                "displayCSS": "transactionID"
                            },
                            "{GUID}:string":{
                                "caption": "GUID",
                                "width": 250,
                                "displayCSS": "GUID"
                            },
                            "orderRow": [
                                {"{transactionID}:number":"DESC"}
                            ],
                            "orderColumn": []
                        }
                        
                    }'
;
    