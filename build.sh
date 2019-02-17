#!/bin/bash
set -e

### Constants ###
DIR_INSTALL=$(pwd)
ENDPATH=$(basename "$DIR_INSTALL")
DRUPAL_DB="$(echo $ENDPATH | sed 's/[^a-zA-Z0-9]//g')"

### These variables need to be set for your instance ###
DATABASE_NAME="SET_THIS_TO_YOUR_STORED_DATABASE_NAME"
DATABASE_LOCATION="SET_THIS_TO_THE_DIRECTORY_WHERE_YOUR_DATABASE_DUMP_LIVES"

### Define colors and cmd-line formatting for output ###
color_green=$'\e[1;32m'
color_yellow=$'\e[1;33m'
color_lt_yellow=$'\e[1;33m'
color_end=$'\e[0m'
bold_start=$'\033[1m'
bold_end=$'\033[1m'
bg_color_red=$'\e[41m'

### FUNCTIONS ###
show_banner() {
	clear
	echo -e "$color_lt_yellow"
	echo -e "┌──────────────────────────────────────────────────────────────────┐"
	echo -e "│                                                                  │"
	echo -e "│                       Drupal 8 Build Script                      │"
	echo -e "│                                                                  │"
	echo -e "└──────────────────────────────────────────────────────────────────┘"
	echo -e "$color_end"
	echo -e "\n\n$bg_color_red    This script MUST be run from the root of the project to work    $color_end\n\n"
}




echo_header() {
	text_bold="$(tput bold)\e[4m"
	text_normal="\e[24m$(tput sgr0)"
	echo -e "\n"
	echo -e "${text_bold}$*${text_normal}"
}




echo_success() {
	text_reverse_bold="$(tput bold)\e[1;32m"
	text_normal="\e[0m$(tput sgr0)"
	echo -e "${text_reverse_bold}$*${text_normal}"
}




import_prod_database() {
	cd $DIR_INSTALL/web
	current_dir=$(pwd)
	cd /var/www/drupal8_storage/db || exit
	IFS= read -r -d '' latest < <(find $DATABASE_NAME* -type f -name '*.sql' -printf '%p\0' | sort -znr)
	cd $current_dir
	cp $DATABASE_LOCATION"$latest" ./"$latest"
	../vendor/bin/drush sql-cli < $latest
	rm $latest
}




copy_local_settings_file() {
	chmod 775 $DIR_INSTALL/web/sites/default
	cd $DIR_INSTALL/web/sites/default

	if [ -f settings.local.php ]; then
		echo_success "-settings.local.php already exists; deleting to create a new one"
		chmod 755 settings.local.php
		rm -f settings.local.php
	fi

	cp $DIR_INSTALL/resources/dev.settings.local.php ./settings.local.php
	sed -i -e "s/DATABASE/$DRUPAL_DB/g" $DIR_INSTALL/web/sites/default/settings.local.php
}




copy_local_services_file() {
	cd $DIR_INSTALL/web/sites/default

	if [ -f services.yml ]; then
		echo_success "-PROD services.yml already exists; replacing with the DEV version"
		chmod 755 services.yml
		rm -f services.yml
	fi

	cp $DIR_INSTALL/resources/services.yml .
	# changes won't be tracked so don't add to repo
	git update-index --assume-unchanged $DIR_INSTALL/resources/services.yml
	chmod 644 services.yml
}




install_composer() {
	cd $DIR_INSTALL
	composer install
	composer clearcache
}




install_site() {
	# Install the site and create an admin/admin user for dev instance
	cd $DIR_INSTALL/web
	../vendor/bin/drush site-install -y
}




install_site_dev() {
	# Install the site and create an admin/admin user for dev instance
	cd $DIR_INSTALL/web
	../vendor/bin/drush site-install --account-name=admin --account-pass=admin -y
}



disable_cache() {
	cd $DIR_INSTALL/web
	echo -e '-Disabling cache'
	../vendor/bin/drush sset cache 0
	echo -e '-Disabling preproces_css'
	../vendor/bin/drush sset preprocess_css 0
	echo -e '-Disabling preprocess_js'
	../vendor/bin/drush sset preprocess_js 0
	echo -e '-Setting page cache maximum age to 0'
	../vendor/bin/drush sset page_cache_maximum_age 0
	echo -e '-Disabling views cache'
	../vendor/bin/drush sset views_skip_cache TRUE
	echo -e '-Setting Drupal dev mode'
	../vendor/bin/drupal site:mode dev
	echo -e '-Dev mode set up'
}




import_configuration() {
	cd $DIR_INSTALL/web
	../vendor/bin/drush config-import -y
}




update_site() {
	cd $DIR_INSTALL
	composer update drupal/core --with-dependencies
	./vendor/bin/drush updatedb -y
	./vendor/bin/drush cr
}




print_completion() {
	ELAPSED=$1
	echo -e "*************************************************************************************************"
	echo -e "*                               Drupal 8 build script completed                                 *"
	echo -e "*************************************************************************************************"
	echo -e "${bold_start}Build time:${bold_end} ${color_green}${ELAPSED}${color_end}"
	echo -e "*************************************************************************************************"
	echo -e "Drupal login is:\n\n${color_green}username: admin\npassword: admin${color_end}\n"
	echo -e "Drupal clear cache: '${color_green}drush cr${color_end}' anywhere under '${color_yellow}/web/${color_end}'"
	echo -e "*************************************************************************************************"
}




### Build functions ###
build_instance_dev() {
	build_color=$color_green
	echo -e "\n\n$build_color$bold_start###############################\n##### DEVELOPMENT TIER #####\n###############################$bold_end$color_end" # 2>&1 | tee -a $logfile

	# Create the services.yml and settings.local.php by copying from the /resources directory
	echo_header "Creating services.yml and settings.local.php"
	chmod 775 $DIR_INSTALL/web/sites/default
	copy_local_settings_file
	copy_local_services_file

	# Install the necessary Composer modules from the repository's composer.json file
	echo_header "Installing Composer Modules (may take a few minutes)"
	install_composer

	# Install Drupal 8 and set up admin/admin account (For dev only; NEVER for prod)
	echo_header "Installing dev site and setting up admin account"
	install_site_dev

	# Import the database from our specified database dump directory
	echo_header "Importing database"
	import_prod_database

	# This is dev, so disable caching
	echo_header "Disabling Drupal cache"
	disable_cache

	# Import the Drupal 8 configuration from prod to dev
	echo_header "importing configuration"
	import_configuration

	# Go back to the root directory and then tell how long it took to run the entire process
	cd $DIR_INSTALL
	ELAPSED="$(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

	print_completion $ELAPSED
}


build_instance_prod() {
	build_color=$color_green
	echo -e "\n\n$build_color$bold_start###############################\n##### DEVELOPMENT TIER #####\n###############################$bold_end$color_end" # 2>&1 | tee -a $logfile

	# Create the services.yml and settings.local.php by copying from the /resources directory
	echo_header "Creating services.yml and settings.local.php"
	chmod 775 $DIR_INSTALL/web/sites/default
	copy_local_settings_file
	copy_local_services_file

	# Install the necessary Composer modules from the repository's composer.json file
	echo_header "Installing Composer Modules (may take a few minutes)"
	install_composer

	# Install Drupal 8 and set up admin/admin account (For dev only; NEVER for prod)
	echo_header "Installing dev site and setting up admin account"
	install_site_dev

	# Import the database from our specified database dump directory
	echo_header "Importing database"
	import_prod_database

	# Go back to the root directory and then tell how long it took to run the entire process
	cd $DIR_INSTALL
	ELAPSED="$(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

	print_completion $ELAPSED
}


##### MAIN #####
show_banner
echo_header "What do you want to do?"
options=(
	"Build Drupal 8 DEV site with database import"
	"Build Drupal 8 PROD site with database import"
	"Quit"
)

select option in "${options[@]}"; do
	case $option in
		"Build Drupal 8 DEV site with database import")
			build_instance_dev
			break
			;;
		"Build Drupal 8 PROD site with database import")
		  build_instance_prod
			break
			;;
		"Quit")
			echo_header "Exiting the script"
			echo -e "Build cancelled...\n\n"
			break
			;;
		*) echo invalid option;;
	esac
done
