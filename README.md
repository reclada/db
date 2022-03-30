### Installation DB
1. Make sure, that you have:
    * psql (psql -V);
    * git (git --version);
    * python (python --version must be 3.X).
2. git clone:
    * ```git clone https://git.../db```
    * ```git clone https://git.../SciNLP```
    * ```git clone https://git.../reclada-runtime```
    * ```git clone https://git.../configurations```
    * ```git clone https://git.../components```
3. Create new environment configuration file (```my_environment.json```) in "configurations" or use existing (```commit``` and ```push``` are optional).
4. Create ```"configuration.json"``` for each component directory (db, SciNLP, reclada-runtime) if you want use custom configuration.
    > ***Note:*** for component "reclada-runtime" is necessary to use custom configuration for correct working (at least should edit ```"LAMBDA_NAME"```)
5. run ```cd components``` 
6. run ```python installer.py my_environment```
### Upgrade DB:
1. Upgrade code on file system;
2. (optional) Edit ```"configuration.json"``` for each component directory (db, SciNLP, reclada-runtime);
3. run ```cd components``` 
4. run ```python installer.py my_environment```
> ***Note:*** For component "db" should use only commits from branch "test" or "master", because every commit must has migration script. Commits without migration script (or incorrect migration script) are invalid.
