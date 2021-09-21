from update_db import clone_db, get_version_from_commit, rmdir, get_commit_history

import os
import json

def main(sbr,dbr):

    source = get_commit_history(sbr)
    dest, cherry = get_commit_history(dbr, True)

    if len(source) <= len(dest):
        print("length of source_branch can not be <= length of destination_branch")
        return
    

    j=0
    pre_valid_commit = 0
    for commit in cherry:
        while j < len(source):
            if commit == source[j]:
                j+=1
                pre_valid_commit += 1
                break
            else:
                j+=1
        else:
            print('"source_branch" and "destination_branch" are too different!!!')
            return

    source = source[j:]

    if len(source) == 0:
        print('There is no updates to publish')
        return
    
    #os.system(f'git checkout {dbr}')
    
    for commit in source:
        commit_v = get_version_from_commit(commit)

        # validate commit_v
        if pre_valid_commit + 1 == commit_v:
            pre_valid_commit +=1
            print(f'\tmerge')
            os.system(f'git checkout {dbr}')
            msg = f'merge version: {commit_v} from {sbr} ({commit})'
            os.system(f'git merge -X theirs {commit} --no-ff -m "{msg}"')

        else:
            print(f'\tis invalid')
    
    os.system(f'git push')


if __name__ == "__main__":
    j = ''
    with open('publish_config.json') as f:
        j = f.read()
    j = json.loads(j)
    sbr = j['source_branch']
    dbr = j['destination_branch']

    clone_db()

    main(sbr,dbr)

    os.chdir('..')
    rmdir('db')