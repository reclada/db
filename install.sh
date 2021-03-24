database=$1
user=$2
if [ -z $database ]; then
    database="reclada";
fi;
if [ -z $user ]; then
    user=$database;
fi;

if [ ! -d postgres-json-schema ]; then
    git clone https://github.com/gavinwahl/postgres-json-schema.git
fi;

cd postgres-json-schema
make install
cd ..

echo $user $database
dropdb $database
dropuser $user
createuser $user -s
createdb $database -O $user
psql $database $user -f scheme.sql
psql $database $user -f functions.sql
psql $database $user -f data.sql
