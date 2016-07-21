# Metabase

If you are new to Heroku, read [this](http://evans.io/legacy/posts/heroku-survival-guide/) 10 minute survival guide first. Then follow [this](http://www.tilcode.com/category/heroku/) setup guide.

This repo is a clone from https://github.com/metabase/metabase-deploy.

At the time of writing (July 2016) Heroku support for Metabase is in Beta, at version 0.18.1. If you view the ReadMe you can see that it basically consists of a button to deploy Metabase directly to Heroku. Clicking the button just takes you to a setup page provided by Metabase.

Note that this button is hardcoded to version 0.18.1 so clicking that button and following the steps will simply redeploy a virgin copy of 0.18.1 into our epmeta Heroku instance.

If you do that, make sure you understand that you must backup the Metabase Heroku Postgres database first!
Our epmeta instance has 2 Postgres databases:

1. The default one, which is used by Metabase to store Metabase users, queries, dashboards etc.

2. The 'data source' database, which holds all the application data for EasyPeasy - this is a daily copy of production. You can identify it easily because it ends with a colour used by Heroku db system (eg. Jade, Gold etc.)

Also be aware that if you re-deploy from Github or from the button described above in the Readme, you will end up with the virgin metabase Procfile and so the background worker that is setup to copy the production EasyPeasy database (2) will no longer execute.

The 0.18.1 guide for running Metabase on Heroku is [here](http://www.metabase.com/docs/v0.18.1/operations-guide/running-metabase-on-heroku.html).

Since Metabase is aready setup, you don't need to read the setup guide, but it is [here](http://www.metabase.com/docs/v0.18.1/setting-up-metabase.html).

## So what is the difference between this repo and the official Metabase repo?
Currently there are only 3 differences between this repo and the official Metabase repo on github:

1. A one-line change to the Procfile to add the worker.

2. A simple script to add Public/Private keys so the worker can create a secure ssh tunnel to production.

3. A 3 line script to copy EasyPeasy production database (called by the worker).

## So why did we clone this?

There are 2 reasons:

1. So we can add a background worker that runs every day to copy EasyPeasy production database to our Metabase installation on Heroku - as this data is what is used as the source for the Metabase reports.

1. So we can more easily do upgrades when new versions of Metabase are released. To understand how to deploy upgraded versions of Metabase see [this quick guide](http://www.metabase.com/docs/v0.18.1/operations-guide/running-metabase-on-heroku#deploying-new-versions-of-metabase).

## How does it work?
In order for a background worker to run inside a Heroku App, you have to specify that worker in the Procfile. Since the github Metabase deploy repository is used by the whole world, we cannot change the original copy of that Procfile, so we must clone it and then add our worker to that Procfile.

To understand the Procfile see [this guide](https://devcenter.heroku.com/articles/procfile).

The Procfile has been changed to add a worker and [the worker](https://scheduler.heroku.com/dashboard) is called by a Heroku Scheduler job, explained [here](https://devcenter.heroku.com/articles/scheduler).

## Security considerations
Our worker must connect to production to grab a copy of the production database to copy over to Heroku. Currently there is no backup job running on Production, so the worker will first create a backup, zip it, then secure copy it to Heroku.

For this to work, the worker uses ssh to reach production. The public key is on production in the user 'Basil' ~/.ssh/authorizedkeys file. The private key is kept on Heroku.

Note that there is a very small security risk (see next paragraph) because the only way to make this work is for the RSA private/public key pair to not use a passphrase. This is because the worker runs as a process so it cannot respond to passphrase requests for the key. But this is still far more secure than using a login password for the 'Basil' account on production! Read more about RSA keys [here](https://help.ubuntu.com/community/SSH/OpenSSH/Keys).

The small security risk is that if some unknown person got access to Heroku epmeta app, they can see the private key since it is stored as an environment variable in the settings tab. They could then use the key to connect to Basil's account on production. But if someone gains access to Heroku, I would say there are bigger problems than this but the first step is to simply remove the public key from Basil's account production.

If you are new to RSA you should understand [this](https://answers.atlassian.com/questions/331668/how-to-rectify-ssh-error-authenticity-of-host-cant-be-established) security warning about known hosts.

## How we created RSA key pair without a password
Like this:

    ssh-keygen -t rsa -N "" -f my.key

`-N ""` tells it to use an empty passphrase (the same as two of the enters in an interactive script)

`-f my.key` tells it to store the key into the file `my.key` (change as you see fit).

Source [here](http://stackoverflow.com/questions/3659602/bash-script-for-generating-ssh-keys).

## How can I test that the keys are deployed successfully to Heroku?
If the keys are successfully installed you can check in one of 2 ways:

1. In the Heroku UI on the Settings tab, click to show the config vars.

2. Log into the Heroku app by starting a one-off dyno.

Note that (1) does not guarantee they are setup correctly so best to also do (2).

    heroku run bash --app epmetab

This will cause the setup.ssh script to execute and you should see it successfully report that it wrote the public and private keys to file and the IP address of production (since it got added to known hosts)

```bash
Running bash on ⬢ epmetab... up, run.8636
Checking if keys exist...
HEROKU_PUBLIC_KEY successfully written to file
HEROKU_PRIVATE_KEY successfully written to file
# 85.159.211.37 SSH-2.0-OpenSSH_6.6p1 Ubuntu-2ubuntu1
# 85.159.211.37 SSH-2.0-OpenSSH_6.6p1 Ubuntu-2ubuntu1
~ $ 
```

If this reports the keys cannot be written, then they were not correctly added to the Heroku settings. See the Problems section at the end.

## How can I test that the steps in the worker script will work?
See (2) just above - since you are now in a bash shell on a one-off dyno of epmeta, at this point you can  manually test the worker by copying and pasting each line of the worker script.

Note that although the dyno is destroyed when you exit the steps are real - they will really create a backup of easypeasy on production, copy it across and recreate the copy on Heroku.

## How can this be improved?
This solution is only suitable for small operations. A few ways it can be improved are:

1. Implement autossh to improve robustness. This is not needed whilst the production database is so small (10MB) but once it gets into the GB range, the chance that the ssh tunnel drops will probably increase. The larger the db is, the longer it will take to copy, hence the probability the ssh connection will drop. There is a great guide [here](https://github.com/kollegorna/heroku-buildpack-autossh) on how to setup autossh - very similar to this solution - and there is also a Heroku buildpack to add autossh.

2. The script that copies the database should not really be responsible for also creating the backup on production. A daily job should be setup on production to create that zip file.

3. Production servers should limit inbound connections. The backup file should really be pushed out, not pulled from Heroku, especially as Heroku has the ability to grab postgres backup files from any http location. See the section 'Import to Postgres' [here](https://devcenter.heroku.com/articles/heroku-postgres-import-export).

4. This might not be the best way to do a Postgres restore, since there are other ways that might be better. More info [here](http://stackoverflow.com/questions/2056876/postgres-clear-entire-database-before-re-creating-re-populating-from-bash-scr) and [here](http://serverfault.com/questions/260607/pg-dump-and-pg-restore-input-file-does-not-appear-to-be-a-valid-archive) on that.

5. It should be possible to create a direct database ssh tunnel and copy the data that way and thus avoid needing to do backup/restores. That would need to be investigated. Some info is [here](http://stackoverflow.com/questions/21575582/ssh-tunneling-from-heroku) - that question actually inspired this solution, so it's a useful reference to read (including the comments).

Note that doing these steps will improve the security and robustness of the solution, separates concerns to where they belong and would simply the worker script.

# Problems & solutions

## What to do if metabase does not start up?
Sometimes metabase can crash or fail to start. The first place to look is in the logs by running this command from local heroku toolbelt:

    heroku logs --app epmeta

Usually it is due to locks not being cleared. There is more info [here](https://github.com/metabase/metabase/issues/2115).

If the problem is due to the database lock issue, you will see this error in the logs:

```
ERROR metabase.core :: Metabase Initialization FAILED:
liquibase.exception.LockException: Could not acquire change log lock.
Currently locked by
79e938c1-be88-44fe-9ad4-4b8c0ad66d8b.prvt.dyno.rt.heroku.com (172.16.71.230) since [timestamp here]
```

To fix it you need to delete the lock by doing [this simple step](http://www.metabase.com/docs/v0.18.1/operations-guide/start#metabase-fails-to-startup) or if you prefer to know more about the inner workings, you can follow these 3 steps:

1. From heroku toolbelt, access the database:

    heroku pg:psql --app epmeta DATABASE

2. Check that the lock matches the one in the log:

    select * from databasechangeloglock

3. Delete the lock (there should only be 1 - if more then add where clause to delete the one you want):

    delete from databasechangelock

Usually even if the lock does not match you can delete it and simply restart the epmeta dyno. More info [here](https://github.com/metabase/metabase/issues/1871).

## What to do if keys are not setup correctly?
You can either manually add the keys in the settings section, or put each key into a local file and run heroku toolbelt commands to add them (this is the preferred way). For example create 2 files in any local folder:

1. epprod.pub.key <- public key

2. epprod.key <- private key

Then run the following commands:

```bash
heroku config:set HEROKU_PRIVATE_KEY="`cat epprod.key`" --app epmeta

heroku config:set HEROKU_PUBLIC_KEY="`cat epprod.key.pub`" --app epmeta
```

Each command should not report any error and you should see the key in the terminal response. NOW DELETE THE KEYFILES, they should not be left lying around on your local machine.

## How to push changes live?
You need to clone this repo first to a local folder.

WARNING: this is destructive, it will completely replace the existing Metabase code. But our database will remain the same so all users, questions etc will be fine, but take a backup of the database first! If running an upgrade find out if there are any metabase database scripts to run.

From inside your local folder (eg cd metabase-deploy):

```bash
git remote add heroku https://git.heroku.com/epmeta.git
git push -f heroku master
```

That push is a force push to overwrite the code. This is normal for deploying code to Heroku. See [this](http://www.metabase.com/docs/v0.18.1/operations-guide/running-metabase-on-heroku.html) guide to understand this more, and how to install new versions of metabase.

## Points to remember when reinstalling or upgrading metabase
Since this repo is 'locked' at version 0.18.1 of metabase, for each new release you will need to update this repo and then push to heroku (see above). Or you could do it like this:

1. Clone a new repo from the new metabase release on github
2. Copy to your new clone the changed Procfile from this repo and the files we added (worker script and setup script)
3. Commit those 3 changes
4. Clone this repo to your local machine
5. Push to heroku
6. Add the RSA keys (see above)
7. Test the keys work (see above)
8. Run manual test of the worker steps (see above)

The worker will then carry on as before.

Upgrading metabase can cause it to crash sometimes. See [this](https://github.com/metabase/metabase/issues/2616) for help.

## How can I restore the metabase database from a backup?
Put the backup in a public http location (eg. dropbox, amazon ecs). See guide [here](https://devcenter.heroku.com/articles/heroku-postgres-import-export).

Then from your local machine:

```bash
heroku pg:backups restore <YOUR PUBLIC URL> DATABASE_URL --app epmata
```
