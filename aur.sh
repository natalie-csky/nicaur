#!/usr/bin/bash

# TODO make sure to also check for *-git aur packages (is that actually necessary?)
# TODO add proper dependency checks, using pacman -Syu directly (makepkg -si doesn't do the trick that often...)
# TODO replace current site-scraping with using the Aurweb RPC interface

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
SEARCH=false

operation_count=0

declare -a targets

if [[ $EUID -eq 0 ]]; then	
	HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
fi

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
					"s")
						SEARCH=true
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
		exit 1
	fi
	set -u

	if [[ $SEARCH = true ]]; then
		if [[ $SYNC = false && $QUERY = false ]]; then
			printf "$ME: invalid option '-s'\n"
			exit 1
		fi
	fi
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
		nicaur $dependency
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
	    	printf "$ME: target not found: $1\n"
			rm -r $1
			exit 1
	    fi
	}
}

query()
{
	for target in $targets; do
		printf "$ME: querying local packages is not yet implemented... :(\n"
		exit 1
	done
}

remove()
{
	if [[ $EUID -ne 0 ]]; then
		printf "$ME: you cannot perform this operation unless you are root.\n"
		exit 1
	fi

	for target in ${targets[*]}; do
		ERROR=false
		pacman -Rs $target || ERROR=true
		rm -r $HOME/.aur/$target 2>/dev/null || ERROR=true
		if [[ $ERROR = true ]]; then
			printf "hey :3\n"
			exit 1
		fi
		
	done

	exit 0
}

sync()
{
	for target in ${targets[*]}; do
		repo_exists=$(git ls-remote "https://aur.archlinux.org/$target.git")
		if [[ -z $repo_exists ]]; then
			printf "$ME: target not found: $target\n"
			exit 1
		fi
	done

	if [[ $SEARCH = true ]]; then
		for target in ${targets[*]}; do
			
			contents=$(curl -s https://aur.archlinux.org/packages/$target)
			contents=${contents/"&#39;"/"'"}
			contents=${contents/"&amp;"/"&"}

			package_details=$(echo $contents | grep -o '<h2>Package Details.*</h2>')
			package_details=${package_details/"<h2>Package Details: "}
			package_details=${package_details/"</h2>"}

			description=$(echo $contents | grep -o '<th>Description:</th>.*</td>')
			description=${description/"<th>Description:</th> <td class=\"wrap\">"}
			description=$(echo $description | cut -f1 -d"<")

			printf "$package_details\n"
			printf "\t$description\n"
		done

		exit 1
	fi

	cd ~/.aur

	download $target
	cd $target

	while ! install $target; do
		continue
	done
}

if [[ $# -eq 0 ]]; then
	printf "$ME: no operation specified\n"
	exit 1
fi

evaluate_arguments $@

if [[ $DEBUG = true ]]; then
	set -x
fi

if [[ $QUERY = true ]]; then
	query

elif [[ $SYNC = true ]]; then
	sync

elif [[ $REMOVE = true ]]; then
	remove
fi

exit 0
