cd /D "%~dp0"
create_up.sql.py
psql -U reclada -p 5432 -h dev-reclada-k8s.c9lpgtggzz0d.eu-west-1.rds.amazonaws.com -d dev3_reclada_k8s -f up.sql