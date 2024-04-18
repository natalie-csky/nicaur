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
#
#

working_directory=$(pwd)
cd ~/Downloads/aur

git clone "https://aur.archlinux.org/$1.git"

cd $1

while true; do
	install()
done

cd $working_directory
return 0


install(){
	printf "Installing $1...\n"

	makepkg -si #2>&1 | tee makepkg.out

	has_missing_dependency=$(cat makepkg.out | grep -Po 'Missing dependencies')
	
	if [[ -n ${has_missing_dependency} ]]; then
		dependency=$(cat makepkg.out | grep -m 1 -Po '\-> \K.*')
		printf "Missing dependency found: $dependency\n"
		aur $dependency
	else
		printf "$1 successfully installed.\n"
		break
	fi

	printf "Attempting to install again...\n"

	#rm makepkg.out
}
