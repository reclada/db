drop VIEW if EXISTS reclada.v_default_display;
CREATE OR REPLACE VIEW reclada.v_default_display
AS
    SELECT       'string' as json_type  , '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}' as template
    UNION SELECT 'number'               , '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'
    UNION SELECT 'boolean'              , '{"caption": "#@#attrname#@#","width": 250,"displayCSS": "#@#attrname#@#"}'
;
    