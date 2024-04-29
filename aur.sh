#!/usr/bin/bash

# exit, when any command fails
set -e

# exit, when non-defined variable is referenced
set -u

# if any command in a pipeline fails, that return code will be used as the return code of the whole pipeline
set -o pipefail

DEBUG=false
REMOVE=false
QUERY=false
SYNC=false
operation_count=0

evaluate_arguments()
{
	for var in $@; do

		if [[ ${var:0:1} == "-" ]]; then

			argument_length=${#var}

			if [[ $argument_length -eq 1 ]]; then
				printf "error: no argument specified...\n"
				exit 1
			fi

			for ((j=1;j<=argument_length-1;j++)); do

				case ${var:$j:1} in
					"d")
						DEBUG=true	
						;;
					"S")
						SYNC=true
						let "operation_count=operation_count+1"
						;;
					"Q")
						QUERY=true
						let "operation_count=operation_count+1"
						;;
					"R")
						REMOVE=true
						let "operation_count=operation_count+1"
						;;
					*)
						printf "error: invalid option -- '${var:$j:1}'\n"
						exit 1
						;;
				esac

			done
		fi
	done

	if [[ $operation_count -ge 2 ]]; then
		printf "error: only one operation may be used at a time...\n"
		exit 1
	fi

	exit 0
}

install()
{
	printf "Installing $1...\n"

	makepkg -si

	# TODO maybe make grep output quiet?
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

download()
{
# if ls finds an existing package, it won't clone
# if it doesn't it clones
# if repo is empty, it fails and removes the empty repo	
	{
	    ls $1 > /dev/null 2>&1 &&
		printf "$1 already cloned, attempting to install...\n"
	} || {
	    if git clone "https://aur.archlinux.org/$1.git" 2>&1 | grep -Pq 'cloned an empty repository.'; then
	    	printf "error: $1 does not exist...\n"
			rm -r $1
			exit 1
	    fi
	}
}

main()
{
	cd ~/.aur
	
	download $1

	cd $1
	
	while ! install $1; do
		continue
	done

	return 0
}

evaluate_arguments "$@"

main $1