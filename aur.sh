#!/usr/bin/bash

# exit, when any command fails
set -e

# exit, when non-defined variable is referenced
set -u

# if any command in a pipeline fails, that return code will be used as the return code of the whole pipeline
set -o pipefail

ME=$(basename "$0")

DEBUG=false
REMOVE=false
QUERY=false
SYNC=false
operation_count=0

#targets=()
declare -a targets

evaluate_arguments()
{
	arguments_left=("$*")

	for arg in $@; do

		if [[ ${arg:0:1} == "-" ]]; then
			arguments_left=${arguments_left/-}
			argument_length=${#arg}

			if [[ $argument_length -eq 1 ]]; then
				printf "$ME: no argument specified\n"
				exit 1
			fi

			for ((j=1;j<=argument_length-1;j++)); do

				case ${arg:$j:1} in
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
						printf "$ME: invalid option -- '${arg:$j:1}'\n"
						exit 1
						;;
				esac

				arguments_left=${arguments_left/${arg:$j:1}}
			done
		fi
	done

	if [[ $operation_count -ge 2 ]]; then
		printf "$ME: only one operation may be used at a time\n"
		exit 1
	fi

	arguments_left=$(echo $arguments_left | awk '{$1=$1};1')

	for arg in $arguments_left; do
		targets+=($arg)
	done

	# TODO maybe figure something out that doesn't involve unsetting 'u'
	set +u
	if [[ $operation_count -eq 1 && ${#targets} -eq 0 ]]; then
		printf "$ME: no targets specified\n"
	fi
	set -u
}

install()
{
	printf "Installing $1...\n"

	makepkg -si

	# TODO maybe make grep output quiet?
	# TODO also, remove makepkg.out...
	has_missing_dependency=$(cat makepkg.out | grep -Po 'Missing dependencies')
	
	if [[ -n ${has_missing_dependency} ]]; then
		dependency=$(cat makepkg.out | grep -m 1 -Po '\-> \K.*')
		printf "Missing dependency found: $dependency\n"
		aur $dependency
	else
		printf "$1 successfully installed\n"
		return 0
	fi

	printf "Attempting to install again...\n"

	return 1
}

download()
{
	{
	    ls $1 > /dev/null 2>&1 &&
		printf "$1 already cloned, attempting to install...\n"
	} || {
	    if git clone "https://aur.archlinux.org/$1.git" 2>&1 | grep -Pq 'cloned an empty repository.'; then
	    	printf "$ME: $1 does not exist\n"
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

if [[ $# -eq 0 ]]; then
	printf "$ME: no operation specified\n"
	exit 1
fi

evaluate_arguments $@

if [[ $DEBUG = true ]]; then
	set -x
fi

main