#!/usr/bin/bash

# Download the aur package
#
# Try installing the aur package
#
# If it failed and there is a dependency, try to install the dependency via 'sudo pacman -Syu' first
# If pacman could not find the package, recursively invoke this script and install the dependency
# If the dependency could still not be met, abort and notify the user about the missing dependency
#
# If the dependency has a dependency, the script will just recursively invoke itself, until all dependencies are installed
# 
# 
# TODO: add check if there are no arguments
#


# exit, when any command fails
set -e

# exit, when non-defined variable is referenced
set -u

# if any command in a pipeline fails, that return code will be used as the return code of the whole pipeline
set -o pipefail

# commands are printed to terminal
# set -x


install()
{
	printf "Installing $1...\n"

	makepkg -si #2>&1 | tee makepkg.out

	has_missing_dependency=$(cat makepkg.out | grep -Po 'Missing dependencies')
	
	if [[ -n ${has_missing_dependency} ]]; then
		dependency=$(cat makepkg.out | grep -m 1 -Po '\-> \K.*')
		printf "Missing dependency found: $dependency\n"
		aur $dependency
	else
		printf "$1 successfully installed.\n"
		return 0
	fi

	printf "Attempting to install again...\n"

	#rm makepkg.out
	return 1
}


main()
{
	if [[ -z $1 ]]; then
		printf "No arguments given.\n"
		exit 1
	fi

	working_directory=$(pwd)
	cd ~/Downloads/aur

	git clone "https://aur.archlinux.org/$1.git"

	cd $1

	while ! install $1; do
		continue
	done

	cd $working_directory
	return 0
}

main $1