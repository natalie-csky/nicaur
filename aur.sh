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

	makepkg -si

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

	return 1
}


main()
{
	cd ~/Downloads/aur
	
	ls $1 2>/dev/null || {
		git clone "https://aur.archlinux.org/$1.git"
	}

	cd $1
	
	while ! install $1; do
		continue
	done

	return 0
}

if [[ $# -eq 0 ]]; then
	printf "No arguments given.\n"
	exit 1
fi

main $1