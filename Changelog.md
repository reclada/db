### version 50
1. Added support of components;
2. Staging: replace view on table;
3. Fixed autogeneration of downgrade script for trigger;
4. Python scripts Refactoring (create class DBHelper);
5. Created classes:
    * View;
    * Function;
    * DBTriggerFunction;
    * DBTrigger (added functionality for using triggers as database objects);
6. Default fields are returned from create/update/list/delete;
7. Added support orderBy for ObjectDisplay.