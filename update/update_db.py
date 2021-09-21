import os
import json
import stat
from pathlib import Path

os.chdir(os.path.dirname(os.path.abspath(__file__)))
j = ''
with open('update_config.json') as f:
    j = f.read()
j = json.loads(j)

branch_db = j["branch_db"]
branch_runtime = j["branch_runtime"]
branch_SciNLP = j["branch_SciNLP"]
branch_QAAutotests = j["branch_QAAutotests"]
server = j["server"]
db = j["db"]
db_user = j["db_user"]
version = j["version"]
quick_install = j["quick_install"]
if version == 'latest':
    config_version = 999999999
else:
    config_version = int(version)

psql_str = f'psql -P pager=off -U {db_user} -p 5432 -h {server} -d {db} '

#zero = 'fbcc09e9f4f5b03f0f952b95df8b481ec83b6685\n'

def run_file(file_name):
    os.system(f'{psql_str} -f {file_name}')

def checkout(to:str = branch_db):
    cmd = f'git checkout {to} -q'
    print(cmd)
    r = os.popen(cmd).read()
    return r

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
    rmdir('db')
    os.system(f'git clone https://github.com/reclada/db')
    os.chdir('db')
    checkout(branch_db)

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

def get_version_from_db():
    # TODO: refactor for using key psql
    res = os.popen(f'{psql_str} -c "select max(ver) from dev.ver;"').readlines()
    cur_ver_db = int(res[2])
    return cur_ver_db

def get_version_from_commit(commit = '', file_name = 'up_script.sql'):
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
    psql_str1 = f'psql -P pager=off -U {db_user} -p 5432 -h {server} -d postgres '
    
    def execute(cmd:str):
        os.system(f'{psql_str1} -c "{cmd}"')
    
    execute(f'''REVOKE CONNECT ON DATABASE {db} FROM PUBLIC, {db_user};''')
    execute(f'''SELECT pg_terminate_backend(pid)        '''
        +   f'''    FROM pg_stat_activity               '''
        +   f'''        WHERE pid <> pg_backend_pid()   '''
        +   f'''           AND datname = '{db}';        ''')
    execute(f'''DROP DATABASE {db};''')
    execute(f'''CREATE DATABASE {db};''')

def run_test():
    rmdir('QAAutotests')
    os.system(f'git clone https://github.com/reclada/QAAutotests')
    os.chdir('QAAutotests')
    os.system(f'git checkout {branch_QAAutotests}')
    os.system(f'pip install -r requirements.txt')
    os.system(f'pytest tests/components/database --alluredir results --log-file=test_output.log')
    os.chdir('..')
    rmdir('QAAutotests')

if __name__ == "__main__":
        
    clone_db()
    cur_ver_db = get_version_from_db()
    print(f'current version database: {cur_ver_db}')

    res = get_commit_history(branch_db)
    
    #res = res[cur_ver:]

    if len(res) == 0:
        print('There is no updates')
    else:
        for commit in res:
            commit_v = get_version_from_commit(commit)
            os.chdir('update')
            print(f'commit: {commit}\tcommit_version: {commit_v}')
            if commit_v == cur_ver_db + 1:
                print('\trun')
                os.system('python create_up.sql.py')
                run_file('up.sql')
                cur_ver_db+=1
            else:
                print(f'\talready applied')
            os.chdir('..')

            if cur_ver_db == config_version:
                break

    os.chdir('..')
    rmdir('db')