# drupalbashinstaller
A Bash script for Drupal 8 based installation. This could be expanded but at least gives the option of installing in a DEV or PROD environment.

DATABASE_NAME is a variable used to store the name of the database into which the dump should be imported.
DATABASE_LOCATION is the location of the database dump to use for import. On PROD the database should already exist, so this is used only on the PROD build.

This is a basic script that I developed for deploying sites at one job site where the servers were running CentOS 7, Composer, Node.js, and various support tools. This allowed the team to deploy the Drupal 8 instance onto production or onto a personal dev environment where code could be developed and content tested.
