#!/bin/bash

##  +-----------------------------------+-----------------------------------+
##  |                                                                       |
##  | Copyright (c) 2018-2020, Andres Gongora <mail@andresgongora.com>.     |
##  |                                                                       |
##  | This program is free software: you can redistribute it and/or modify  |
##  | it under the terms of the GNU General Public License as published by  |
##  | the Free Software Foundation, either version 3 of the License, or     |
##  | (at your option) any later version.                                   |
##  |                                                                       |
##  | This program is distributed in the hope that it will be useful,       |
##  | but WITHOUT ANY WARRANTY; without even the implied warranty of        |
##  | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         |
##  | GNU General Public License for more details.                          |
##  |                                                                       |
##  | You should have received a copy of the GNU General Public License     |
##  | along with this program. If not, see <http://www.gnu.org/licenses/>.  |
##  |                                                                       |
##  +-----------------------------------------------------------------------+


##
##	DESCRIPTION
##
##	This script updates your "PS1" environment variable to display colors.
##	Additionally, it also shortens the name of your current path to a 
##	maximum 25 characters, which is quite useful when working in deeply
##	nested folders.
##
##
##
##	REFFERENCES
##
##	* http://tldp.org/HOWTO/Bash-Prompt-HOWTO/index.html
##
##



##==============================================================================
##	EXTERNAL DEPENDENCIES
##==============================================================================
[ "$(type -t include)" != 'function' ]&&{ include(){ { [ -z "$_IR" ]&&_IR="$PWD"&&cd "$(dirname "${BASH_SOURCE[0]}")"&&include "$1"&&cd "$_IR"&&unset _IR;}||{ local d="$PWD"&&cd "$(dirname "$PWD/$1")"&&. "$(basename "$1")"&&cd "$d";}||{ echo "Include failed $PWD->$1"&&exit 1;};};}

include '../bash-tools/bash-tools/color.sh'
include '../bash-tools/bash-tools/shorten_path.sh'
include '../config/synth-shell-prompt.config.default'






synth_shell_prompt()
{
##==============================================================================
##	FUNCTIONS
##==============================================================================


##------------------------------------------------------------------------------
##	getGitInfo
##	Returns current git branch for current directory, if (and only if)
##	the current directory is part of a git repository, and git is installed.
##
##	In addition, it adds a symbol to indicate the state of the repository.
##	By default, these symbols and their meaning are (set globally):
##
##		UPSTREAM	NO CHANGE		DIRTY
##		up to date	SSP_GIT_SYNCED		SSP_GIT_DIRTY
##		ahead		SSP_GIT_AHEAD		SSP_GIT_DIRTY_AHEAD
##		behind		SSP_GIT_BEHIND		SSP_GIT_DIRTY_BEHIND
##		diverged	SSP_GIT_DIVERGED	SSP_GIT_DIRTY_DIVERGED		
##
##	Returns an empty string otherwise.
##
##	Inspired by twolfson's sexy-bash-prompt:
##	https://github.com/twolfson/sexy-bash-prompt
##
getGitBranch()
{
	if ( which git > /dev/null 2>&1 ); then

		## CHECK IF IN A GIT REPOSITORY, OTHERWISE SKIP
		local branch=$(git branch 2> /dev/null |\
		             sed -n '/^[^*]/d;s/*\s*\(.*\)/\1/p')

		if [[ -n "$branch" ]]; then

			## GET GIT STATUS
			## This information contains whether the current branch is
			## ahead, behind or diverged (ahead & behind), as well as
			## whether any file has been modified locally (is dirty).
			## --porcelain: script friendly output.
			## -b:          show branch tracking info.
			## -u no:       do not list untracked/dirty files
			## From the first line we get whether we are synced, and if
			## there are more lines, then we know it is dirty.
			## NOTE: this requires that you fetch your repository,
			##       otherwise your information is outdated.
			local is_dirty=false &&\
				       [[ -n "$(git status --porcelain)" ]] &&\
				       is_dirty=true
			local is_ahead=false &&\
				       [[ "$(git status --porcelain -u no -b)" == *"ahead"* ]] &&\
				       is_ahead=true
			local is_behind=false &&\
				        [[ "$(git status --porcelain -u no -b)" == *"behind"* ]] &&\
				        is_behind=true


			## SELECT SYMBOL
			if   $is_dirty && $is_ahead && $is_behind; then
				local symbol=$SSP_GIT_DIRTY_DIVERGED
			elif $is_dirty && $is_ahead; then
				local symbol=$SSP_GIT_DIRTY_AHEAD
			elif $is_dirty && $is_behind; then
				local symbol=$SSP_GIT_DIRTY_BEHIND
			elif $is_dirty; then
				local symbol=$SSP_GIT_DIRTY
			elif $is_ahead && $is_behind; then
				local symbol=$SSP_GIT_DIVERGED
			elif $is_ahead; then
				local symbol=$SSP_GIT_AHEAD
			elif $is_behind; then
				local symbol=$SSP_GIT_BEHIND
			else
				local symbol=$SSP_GIT_SYNCED
			fi


			## RETURN STRING
			echo "$branch$symbol"	
		fi
	fi
	
	## DEFAULT
	echo ""
}

getTerraform()
{
	## Check if we are in a terraform directory
	if [ -d .terraform ]; then
		## Check if the terraform binary is in the path
		if ( which terraform > /dev/null 2>&1 ); then
			## Get the terraform workspace
			local tf="$(terraform workspace show 2> /dev/null | tr -d '\n')"
			echo "$tf"
		fi
	fi
}

getPyenv()
{
	if [ -n "$VIRTUAL_ENV" ]; then
		local pyenv=$(basename ${VIRTUAL_ENV})
		echo "$pyenv"
	fi
}



printSegment()
{
	## GET PARAMETERS
	local text=$1
	local font_color=$2
	local background_color=$3
	local next_background_color=$4
	local font_effect=$5


	## COMPUTE COLOR FORMAT CODES
	local no_color="\[$(getFormatCode -e reset)\]"
	local text_format="\[$(getFormatCode -c $font_color -b $background_color -e $font_effect)\]"
	local separator_format="\[$(getFormatCode -c $background_color -b $next_background_color)\]"


	## GENERATE TEXT
	printf "${text_format}${segment_padding}${text}${segment_padding}${separator_padding_left}${separator_format}${separator_char}${separator_padding_right}${no_color}"
}



get_colors_for_element()
{
	case $1 in
		"USER")  echo "${SSP_COLORS_USER[@]}" ;;
		"HOST")  echo "${SSP_COLORS_HOST[@]}" ;;
		"PWD")   echo "${SSP_COLORS_PWD[@]}"  ;;
		"GIT")   echo "${SSP_COLORS_GIT[@]}"  ;;
		"PYENV") echo "${SSP_COLORS_PYENV[@]}";;
		"TF")    echo "${SSP_COLORS_TF[@]}"   ;;
		"INPUT") echo "${SSP_COLORS_INPUT[@]}";;
		*)
	esac 
}



combine_elements()
{
	local first=$1
	local second=$2
	local colors_first=($(get_colors_for_element $first))
	local colors_second=($(get_colors_for_element $second))


	case $first in
		"USER")  local text="$user" ;;
		"HOST")  local text="$host" ;;
		"PWD")   local text="$path" ;;
		"GIT")   local text="$git_branch" ;;
		"PYENV") local text="$pyenv" ;;
		"TF")    local text="$tf" ;;
		"INPUT") local text="" ;;
		*)       local text="" ;;
	esac


	local text_color=${colors_first[0]}
	local bg_color=${colors_first[1]}
	local next_bg_color=${colors_second[1]}
	local text_effect=${colors_first[2]}
	printSegment "$text" "$text_color" "$bg_color" "$next_bg_color" "$text_effect"
}




##==============================================================================
##	HOOK
##==============================================================================

prompt_command_hook()
{
	## GET PARAMETERS
	## This might be a bit redundant, but it makes it easier to maintain
	local elements=(${SSP_ELEMENTS[@]})
	local user=$USER
	local host=$HOSTNAME
	local path="$(shortenPath "$PWD" 20)"
	local git_branch="$(getGitBranch)"
	local pyenv="$(getPyenv)"
	local tf="$(getTerraform)"


	## ADAPT DYNAMICALLY ELEMENTS TO BE SHOWN
	## Check if elements such as GIT and the Python environment should be
	## shown and adapt the variables as needed. This usually implies removing
	## the appropriate field from the "elements" array if the user set them
	if [ -z "$git_branch" ]; then
		elements=( ${elements[@]/"GIT"} ) # Remove GIT from elements to be shown
	fi
	
	if [ -z "$pyenv" ]; then
		elements=( ${elements[@]/"PYENV"} ) # Remove PYENV from elements to be shown
	fi

	if [ -z "$tf" ]; then
		elements=( ${elements[@]/"TF"} ) # Remove TF from elements to be shown
	fi


	## WINDOW TITLE
	## Prevent messed up terminal-window titles, must be set in the PS1 variable
	case $TERM in
	xterm*|rxvt*)
		SSP_PWD="$path"
		local titlebar="\[\033]0;\${USER}@\${HOSTNAME}: \${SSP_PWD}\007\]"
		;;
	*)
		local titlebar=""
		;;
	esac


	## CONSTRUCT PROMPT ITERATIVELY
	## Iterate through all elements to be shown and combine them. Stop once only
	## 1 element is left, which should be the "INPUT" element; then apply the
	## INPUT formatting.
	## Notice that this reuses the PS1 variables over and over again, and appends
	## all extra formatting elements to the end of it.
	PS1="${titlebar}${SSP_VERTICAL_PADDING}"
	while [ "${#elements[@]}" -gt 1 ]; do
		local current=${elements[0]}
		local next=${elements[1]}
		local elements=("${elements[@]:1}") #remove the 1st element

		PS1="$PS1$(combine_elements $current $next)"
	done

	local input_colors=($(get_colors_for_element ${elements[0]}))
	local input_color=${input_colors[0]}
	local input_bg=${input_colors[1]}
	local input_effect=${input_colors[2]}
	local input_format="\[$(getFormatCode -c $input_color -b $input_bg -e $input_effect)\]"
	PS1="$PS1 $input_format"


	## Once this point is reached, PS1 is formatted and set. The terminal session
	## will then use that variable to prompt the user :)
}






##==============================================================================
##	MAIN
##==============================================================================

	## LOAD USER CONFIGURATION
	local user_config_file="$HOME/.config/synth-shell/synth-shell-prompt.config"
	local root_config_file="/etc/synth-shell/synth-shell-prompt.root.config"
	local sys_config_file="/etc/synth-shell/synth-shell-prompt.config"
	if   [ -f $user_config_file ]; then
		source $user_config_file
	elif [ -f $root_config_file  -a "$USER" == "root"  ]; then
		source $root_config_file
	elif [ -f $sys_config_file ]; then
		source $sys_config_file
	fi


	## PADDING
	if $enable_vertical_padding; then
		local vertical_padding="\n"
	else
		local vertical_padding=""
	fi


    ## CONFIG FOR "prompt_command_hook()"
	SSP_ELEMENTS=($format "INPUT") # Append INPUT to elements that have to be shown
	SSP_COLORS_USER=($font_color_user $background_user $texteffect_user)
	SSP_COLORS_HOST=($font_color_host $background_host $texteffect_host)
	SSP_COLORS_PWD=($font_color_pwd $background_pwd $texteffect_pwd)
	SSP_COLORS_GIT=($font_color_git $background_git $texteffect_git)
	SSP_COLORS_PYENV=($font_color_pyenv $background_pyenv $texteffect_pyenv)
	SSP_COLORS_TF=($font_color_tf $background_tf $texteffect_tf)
	SSP_COLORS_INPUT=($font_color_input $background_input $texteffect_input)
	SSP_VERTICAL_PADDING=$vertical_padding

	SSP_GIT_SYNCED=$git_symbol_synced
	SSP_GIT_AHEAD=$git_symbol_unpushed
	SSP_GIT_BEHIND=$git_symbol_unpulled
	SSP_GIT_DIVERGED=$git_symbol_unpushedunpulled
	SSP_GIT_DIRTY=$git_symbol_dirty
	SSP_GIT_DIRTY_AHEAD=$git_symbol_dirty_unpushed
	SSP_GIT_DIRTY_BEHIND=$git_symbol_dirty_unpulled
	SSP_GIT_DIRTY_DIVERGED=$git_symbol_dirty_unpushedunpulled


	## For terminal line coloring, leaving the rest standard
	none="$(tput sgr0)"
	trap 'echo -ne "${none}"' DEBUG


	## ADD HOOK TO UPDATE PS1 AFTER EACH COMMAND
	## Bash provides an environment variable called PROMPT_COMMAND.
	## The contents of this variable are executed as a regular Bash command
	## just before Bash displays a prompt.
	## We want it to call our own command to truncate PWD and store it in NEW_PWD
	PROMPT_COMMAND=prompt_command_hook
}






## CALL SCRIPT FUNCTION
## - CHECK IF SCRIPT IS _NOT_ BEING SOURCED
## - CHECK IF COLOR SUPPORTED
##     - Check if compliant with Ecma-48 (ISO/IEC-6429)
##	   - Call script
## - Unset script
## If not running interactively, don't do anything
if [ -n "$( echo $- | grep i )" ]; then

	if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
		echo -e "Do not run this script, it will do nothing.\nPlease source it instead by running:\n"
		echo -e "\t. ${BASH_SOURCE[0]}\n"

	elif [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
		synth_shell_prompt
	fi
	unset synth_shell_prompt
	unset include
fi
