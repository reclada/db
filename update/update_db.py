import os
import json
import stat
from pathlib import Path
import sys
import urllib.parse
import uuid
import shutil


os.chdir(os.path.dirname(os.path.abspath(__file__)))
j = ''
with open('update_config.json') as f:
    j = f.read()
j = json.loads(j)

branch_db = j["branch_db"]
branch_runtime = j["branch_runtime"]
branch_SciNLP = j["branch_SciNLP"]
branch_QAAutotests = j["branch_QAAutotests"]

db_URI = j["db_URI"]
parsed = urllib.parse.urlparse(db_URI)
db_URI = db_URI.replace(parsed.password, urllib.parse.quote(parsed.password))

db_user = parsed.username
db_name = db_URI.split('/')[-1]
ENVIRONMENT_NAME = j["ENVIRONMENT_NAME"]
LAMBDA_NAME = j["LAMBDA_NAME"]
LAMBDA_REGION = j["LAMBDA_REGION"]
version = j["version"]
quick_install = j["quick_install"]
downgrade_test = j["downgrade_test"]
if version == 'latest':
    config_version = 999999999
else:
    config_version = int(version)


def psql_str(cmd:str,DB_URI:str = db_URI)->str:
    return f'psql -t -P pager=off {cmd} {DB_URI}'

#zero = 'fbcc09e9f4f5b03f0f952b95df8b481ec83b6685\n'

def pg_dump(file_name:str,t:str):
    os.system(f'pg_dump -N public -f {file_name} -O {db_URI}')

    with open('up_script.sql',encoding='utf8') as f:
        ver_str = f.readline()
        ver = int(ver_str.replace('-- version =',''))
            
    with open(file_name,encoding='utf8') as f:
        scr_str = f.readlines()

    with open(file_name,'w',encoding='utf8') as f:
        f.write(ver_str)
        f.write(f'-- {t}')
        for line in scr_str:
            if line.find('GRANT') != 0 and line.find('REVOKE') != 0:
                f.write(line)


def json_schema_install(DB_URI=db_URI):
    file_name = 'patched.sql'
    clone('postgres-json-schema','https://github.com/gavinwahl/postgres-json-schema.git')
    with open('postgres-json-schema--0.1.1.sql') as s, open(file_name,'w') as d:
        d.write(s.read().replace('@extschema@','public').replace('CREATE OR REPLACE FUNCTION ','CREATE OR REPLACE FUNCTION public.'))

    run_file(file_name,DB_URI)
    os.chdir('..')
    rmdir('postgres-json-schema')


def clone(component_name:str,repository:str,branch:str='',debug_db=False):
    # folder: update
    rmdir(component_name)
    os.chdir('..') #folder: db
    os.chdir('..') #folder: repos

    if not (os.path.exists(component_name) and os.path.isdir(component_name)):
        os.system(f'git clone {repository}')
        os.chdir(component_name)
        if branch != '':
            res = checkout(branch)
        # else use default branch
        os.chdir('..')

    folder_source = component_name
    if component_name == 'db':
        folder_source = f'db_copy_{str(uuid.uuid4())}'
        shutil.copytree('db',folder_source)
        if not debug_db:
            os.chdir(folder_source)
            res = checkout(branch)
            os.chdir('..')
    
    path_dest = os.path.join('db','update',component_name)

    shutil.copytree(folder_source, path_dest)
    if component_name == 'db':
        rmdir(folder_source)

    os.chdir(path_dest)
    
    #folder: repos/db/update/component_name
        

def get_repo_hash(component_name:str,repository:str,branch:str,debug_db=False):
    # folder: db/update
    rmdir(component_name)
    clone(component_name,repository,branch,debug_db)
    #folder: repos/db/update/component_name
    cmd = "git log --pretty=format:%H -n 1"
    repo_hash = os.popen(cmd).read()
    return repo_hash

#{ Components

def install_objects(l_name=LAMBDA_NAME, l_region=LAMBDA_REGION, e_name=ENVIRONMENT_NAME, DB_URI=db_URI):
    exists = Path('update').exists()
    if exists:
        os.chdir('update') # for lower 48 don't need
    file_name = 'object_create_patched.sql'
    with open('object_create.sql') as f:
        obj_cr = f.read()

    obj_cr = obj_cr.replace('#@#lname#@#', l_name)
    obj_cr = obj_cr.replace('#@#lregion#@#', l_region)
    obj_cr = obj_cr.replace('#@#ename#@#', e_name)

    with open(file_name,'w') as f:
        f.write(obj_cr)

    run_file(file_name,DB_URI)
    os.remove(file_name)

    if exists:
        os.chdir('..')


def run_file(file_name,DB_URI=db_URI):
    cmd = psql_str(f'-f "{file_name}"',DB_URI)
    os.system(cmd)


def run_cmd_scalar(command,DB_URI=db_URI)->str:
    command = command.replace('"','""').replace('\n',' ')
    cmd = psql_str(f'-c "{command}"',DB_URI)
    res = os.popen(cmd).read().strip()
    return res


def checkout(to:str = branch_db):
    cmd = f'git status'
    r = os.popen(cmd).read()
    if r.find('nothing to commit, working tree clean')<0:
        cmd = f'git clean -fxd -q'
        r = os.popen(cmd).read()
        cmd = f'git checkout . -q'
        r = os.popen(cmd).read()
    if to != '':
        cmd = f'git checkout {to} -q'
        r = os.popen(cmd).read()
    return r

def runtime_install():
    install_psql_script('db/objects',["install_objects.sql"])


def scinlp_install():
    install_psql_script('src/db',["bdobjects.sql","nlpobjects.sql","nlpatterns.sql"])


def install_psql_script(directory:str,files:list):
    path = directory.split('/')
    os.chdir(os.path.join(*path))
    for f in files:
        run_file(f)
    for _ in range(len(path)):
        os.chdir('..')

#} Components

def replace_component(name:str,repository:str,branch:str,component_installer,debug_db=False)->str:
    '''
        replace or install reclada-component
    '''
    print(f'installing component "{name}"...')
    guid = run_cmd_scalar(f"SELECT guid FROM reclada.v_component WHERE name = '{name}'")

    repo_hash = get_repo_hash(name,repository,branch,debug_db)
    if guid != '':
        db_hash = run_cmd_scalar(f"SELECT commit_hash FROM reclada.v_component WHERE guid = '{guid}'")
        if db_hash == repo_hash:
            os.chdir('..')
            rmdir(name)
            print(f'Component {name} has actual version')
            return

    cmd = f"SELECT dev.begin_install_component('{name}','{repository}','{repo_hash}');"
    res = run_cmd_scalar(cmd)
    if res == 'OK':
        component_installer()
        cmd = "SELECT dev.finish_install_component();"
        res = run_cmd_scalar(cmd)
        if res != 'OK':
            raise Exception('Component does not installed')
    os.chdir('..')
    rmdir(name)


def rmdir(top:str): 
    if os.path.exists(top) and os.path.isdir(top):
        for root, dirs, files in os.walk(top, topdown=False):
            for name in files:
                filename = os.path.join(root, name)
                os.chmod(filename, stat.S_IWUSR)
                os.remove(filename)
            for name in dirs:
                os.rmdir(os.path.join(root, name))
        os.rmdir(top)


def clone_db():
    clone('db', 'db', branch_db)


def get_commit_history(branch:str = branch_db, need_comment:bool = False):
    checkout(branch)
    
    res = os.popen(f'git log --pretty=format:"%H" --first-parent fbcc09e9f4f5b03f0f952b95df8b481ec83b6685..').readlines()
    for i in range(len(res)):
        res[i]=res[i].strip()
    res.reverse()
    if need_comment:
        res2 = os.popen('git log --pretty=format:"%B" --first-parent fbcc09e9f4f5b03f0f952b95df8b481ec83b6685..').readlines()
        while('\n' in res2):
            res2.remove('\n')
        for i in range(len(res2)):
            s = res2[i]
            res2[i] = s=s[s.find('(')+1:s.find(')')]
        res2.reverse()

    pre_valid_commit = 0
    i = 0
    remove_index = []
    for commit in res[:]:
        commit_v = get_version_from_commit(commit)
        os.chdir('update')
        # validate commit_v
        if pre_valid_commit + 1 == commit_v:
            pre_valid_commit +=1
        else:
            remove_index.append(i)
            if '4e175924faa761be367b19f62034057c1498fcb7' != commit:
                print(f'\tcommit: {commit} is invalid')
        i+=1
        os.chdir('..')
        
    for i in reversed(remove_index):
        del res[i]
        if need_comment:
            del res2[i]

    if need_comment:
        return res, res2

    return res


def get_version_from_db(DB_URI=db_URI)->int:
    return int(run_cmd_scalar("select max(ver) from dev.ver;",DB_URI))


def get_version_from_commit(commit = '', file_name = 'up_script.sql')->int:
    if commit != '':
        checkout(commit)
    cd = Path('update').exists()
    if cd:
        os.chdir('update')
    commit_v = -1
    if not Path(file_name).exists():
        return commit_v
    with open(file_name, encoding='utf8') as f:
        for line in f:
            p = '-- version ='
            if line.startswith(p):
                commit_v = int(line.replace(p,''))
                break
    if cd:
        os.chdir('..')
    return commit_v


def recreate_db():
    
    splt = db_URI.split('/')
    splt[-1] = 'postgres'
    db_URI_postgres = '/'.join(splt)
    
    def execute(cmd:str):
        run_cmd_scalar(cmd, db_URI_postgres)
    
    execute(f'''REVOKE CONNECT ON DATABASE {db_name} FROM PUBLIC, {db_user};''')
    execute(f'''SELECT pg_terminate_backend(pid)        
                    FROM pg_stat_activity               
                    WHERE pid <> pg_backend_pid()   
                        AND datname = '{db_name}';''')
    execute(f'''DROP DATABASE {db_name};''')
    execute(f'''CREATE DATABASE {db_name};''')

def run_test():
    clone('QAAutotests', 'https://github.com/reclada/QAAutotests.git', branch_QAAutotests)
    os.system(f'pip install -r requirements.txt')
    os.system(f'pytest '
        + 'tests/components/security/test_database_sql_injections.py '
        + 'tests/components/database '
        + 'tests/components/postgrest '
        + '--alluredir results --log-file=test_output.log')
    os.chdir('..')
    rmdir('QAAutotests')

def install_components(debug_db=False):
    v = get_version_from_db()
    if v < 48: # Components do not exist before 48
        install_objects() 
    else:
        replace_component('db','https://gitlab.reclada.com/developers/db.git',branch_db,install_objects,debug_db)
        replace_component('SciNLP','https://gitlab.reclada.com/developers/SciNLP.git',branch_SciNLP,scinlp_install)
        replace_component('reclada-runtime','https://gitlab.reclada.com/developers/reclada-runtime.git',branch_runtime,runtime_install)

def clear_db_from_components():
    print('clear db from components...')
    res = run_cmd_scalar('''DO
                            $do$
                            DECLARE
                                _objs  jsonb[];
                            BEGIN
                                SELECT array_agg(distinct obj_data)
                                    FROM reclada.v_component_objects o
                                    INTO _objs;
                                
                                select reclada_object.delete(cn)
                                    from unnest(_objs) AS cn;
                            END
                            $do$;''')#to delete indexes

    res = run_cmd_scalar('''WITH t as (
                                SELECT object, subject, guid 
                                    FROM reclada.v_relationship
                                        WHERE type = 'data of reclada-component'
                            )
                            DELETE FROM reclada.object 
                                WHERE guid in 
                                (   
                                    SELECT object  FROM t
                                    UNION
                                    SELECT subject FROM t
                                    UNION
                                    SELECT guid    FROM t
                                    UNION 
                                    SELECT guid    FROM reclada.v_component
                                );''')
    print(res)
    res = run_cmd_scalar('''DELETE FROM reclada.object 
                                WHERE guid in 
                                (
                                    SELECT r.obj_id
                                        FROM reclada.v_revision r
                                );''')
    print(res)
    res = run_cmd_scalar('''UPDATE reclada.object 
                                SET attributes = attributes - 'revision';''')
    print(res)
    res = run_cmd_scalar('''DELETE FROM dev.component_object;''')
    print(res)
    res = run_cmd_scalar('''SELECT reclada_object.refresh_mv('All');''')
    print(res)


if __name__ == "__main__":
        
    DB_URI = db_URI
    if len(sys.argv) > 1:
        DB_URI = sys.argv[1]

    clone_db()
    cur_ver_db = get_version_from_db(DB_URI)
    print(f'current version database: {cur_ver_db}')

    res = get_commit_history(branch_db)
    
    #res = res[cur_ver:]

    if len(res) == 0:
        print('There is no updates')
    else:
        for commit in res:
            commit_v = get_version_from_commit(commit)
            os.chdir('update')
            if commit_v == cur_ver_db + 1:
                print(f'commit: {commit}\tcommit_version: {commit_v}')
                os.system('python create_up.sql.py')
                run_file('up.sql',DB_URI)
                cur_ver_db+=1
            os.chdir('..')

            if cur_ver_db == config_version:
                break

    if cur_ver_db >= 48: # Components do not exist before 48
        install_components() #upgrade components
    
    os.chdir('..')
    rmdir('db')