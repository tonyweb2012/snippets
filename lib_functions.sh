#!/usr/bin/env bash

#Sanity checks: Detect if lib script is being sourced or called directly
if [[ $0 == $BASH_SOURCE ]]; then
    echo "You cannot run this script directly"
    echo "It is a library file"
    exit 255
fi

LIB_NAME="$(basename "$(realpath "$BASH_SOURCE")")"
LIB_HOME="$(dirname  "$(realpath "$BASH_SOURCE")")"
LOG_DATE=$(date '+%Y%m%d')
LOG_FOLDER="/secbin/log"
LOG_EXTEN="log"

#######################
# Vars
####

DISABLE_COLOR=0

if [[ ${DISABLE_COLOR} -ne 1 ]]; then
    # Shell colors declaration
    txtund=$(tput sgr 0 1)           # Underline
    txtbld=$(tput bold)              # Bold
    bldred=${txtbld}$(tput setaf 1)  #  red
    bldgre=${txtbld}$(tput setaf 2)  #  green
    bldyell=${txtbld}$(tput setaf 3) #  yellow
    bldblu=${txtbld}$(tput setaf 4)  #  blue
    bldwht=${txtbld}$(tput setaf 7)  #  white
    txtrst=$(tput sgr0)              # Reset
    txtblue=$(tput setaf 4)          #  blue
    txtgreen=$(tput setaf 2)         #  green
    txtyell=$(tput setaf 3)          #  yellow
    txtred=$(tput setaf 1)           #  green
    txtcya=$(tput setaf 14)          #  cyan
else
    txtund=""
        txtbld=""
    bldred=""
    bldgre=""
    bldyell=""
    bldblu=""
    bldwht=""
    txtrst=""
    txtblue=""
    txtblue=""
    txtyell=""
    txtred=""
    txtcya=""
fi

# other variables goes below

#######################
# Error handling
####

# Function called while an error happend (every non exit 0 status)
# 3 args: 1: Error line, 2: exit code, 3: Error file
trap_handling() {
    echo  ${bldred}"${3}"${txtrst}":"${bldred}"${1}"${txtrst}" exited with unexpected error "${bldred}"${2} !"${txtrst}
    exit ${2}
}

# Exit handling function. Will be called on every exit code
## If exist, exit_custom will be called to run specific exit tasks.
exit_handling() {
    if [[ ${1} -ne 0 ]]; then
        f_log_error "Script terminated with exit code ${1}"
    else
        f_log_info "Script terminated succesfully"
    fi

    if [ "$(declare -F exit_custom &>/dev/null ; echo $?)" -eq 0 ]; then
        echo "Calling exit_custom()"
        exit_custom
    fi
    exit $1
    exit 255 # Exit with error in case return code is not provided
}

# Function to setup error handling on non 0 status
error_set() {
    set -o pipefail  # trace ERR through pipes
    set -o errtrace  # trace ERR through 'time command' and other functions
    set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
    set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

    trap 'status=$? ; trap_handling $LINENO $status $BASH_SOURCE' ERR
    trap 'status=$? ; exit_handling $status' EXIT
}

# WARNING! Error handling will not be set unless you call the error_set fuction into your script!

#######################
# Functions
####

# Cleanup/Remove files
cleanup_files() {
    [[ -f ${A_PROFILE_FILE} ]] && rm -f ${A_PROFILE_FILE}
    exit 1
}

# trap ctrl-c and call cleanup_files()
trap cleanup_files INT

# If previous command didn't exit with status 0, show a message and exit
check_error() {
    if [[ $? -ne 0 ]]; then
        echo "${bldred}An Error Occured !${txtrst}";
        cleanup_files
        exit 1
    fi
}

# Exit with 2 if user is not root.
# Unless, return 0
check_root() {
    if [[ $(whoami) != "root" ]]; then
        echo ${txtred}" --> Script must be run as root"${txtrst}
        exit 2
    fi
}

# Return 0 if yes, 1 if no. Other anwser will loop into the function
yes_no() {
    # If quickmode is activated return 1 or 0 following the checklist input
    if [[ ${A_QUICK_MODE_FLAG} -eq 1 && $1 != "" ]]; then
        if grep -q "\"$1\"" ${A_PROFILE_FILE}; then
            echo " -> FLAG set to on, processing ..."
            return 0
        else
            echo " -> FLAG set to off, skipping"
            return 1
        fi
    fi

    read -r

    #If fast mode is activated we skip as much prompt as we can !
    if [[ ${A_NO_INTERACTION_FLAG} -eq  1 ]]; then
        return 0
    fi

    case ${REPLY} in
        y|yes|Y|Yes|YES)    return 0
        ;;
        n|no|N|NO)          return 1
        ;;
        *)                  yes_no
        ;;
    esac
}

# No return code, only wait for user
wait_user() {
    if [[ ${A_NO_INTERACTION_FLAG} -ne  1 ]]; then
        echo ${txtblue}"-----> Press Enter to continue "${txtrst}
        read
    fi
}

# Execute command with sudo -u SUDO_USER on remote host
# remote_ssh_with_sudo <Remote host> <Remote command>
remote_ssh_with_sudo () {
  local ssh_sudo_user=""

  if [[ ! ${1:-} ]]; then
    f_log_error "target not defined"
    return 101
  fi

  if [[ ! ${2:-} ]]; then
    f_log_error "No remote command to execute!"
    return 102
  fi

  if [[ ${SUDO_USER:0:5} =~ ^[a-z]{2}[0-9]{3}$ ]]; then
    ssh_sudo_user="${SUDO_USER:0:5}"
  else
    ssh_sudo_user="${SUDO_USER}"
  fi
  echo "ssh $1 \"sudo -u ${ssh_sudo_user} ${2}\""
  ssh $1 "sudo -u ${ssh_sudo_user} ${2}"
  return $?
}

##############################################
# f_check_host_reachability : ping + ssh
##############################################
f_check_host_reachability() {
  hostname=${1}
  if ping -c 1 ${hostname} &>/dev/null ; then
    if ssh  "${hostname}" ":" ; then
      return 0
    else
      f_log_error "Can't SSH to ${hostname} ! (or connection too slow)"
    fi
  else
    f_log_error "Can't ping ${hostname}"
  fi

  return 1
}

##############################################
# logging : different types of messages : INFO, WARN, CRIT, DEBUG
##############################################
# To log and output, just use the builtin functions :
# - f_log_info  : green and just informative, logged to file
# - f_log_warn  : yellow, informative, logged to file
# - f_log_error : red, when called, logged to file
# - f_log_debug : White, not logged into file
# If you don't want to log, NO_LOGFILE is set to true|TRUE|yes|enabled|YES
# logs will *NOT* be writen to file. Need to be set before lib sourcing!

f_log_debug() {
  if [[ "${DEBUG:+1}" ]] ; then
    if [[ ${DEBUG^^} =~ ^(TRUE|ENABLED|YES|1)$ ]] ; then
      echo "[ DEBG ] ${1:?'No Message provided...'}${txtrst}"
    fi
  fi
}
f_log_info() {
  f_log_caller_name # will setup CALLER_NAME var with the name of launched script.
  echo "[${bldgre} INFO ${txtrst}] ${txtgreen}${1:?'No Message provided...'}${txtrst}"
  f_log_write "[ INFO ] ${1:?'No Message provided...'}"
}
f_log_warn() {
  f_log_caller_name # will setup CALLER_NAME var with the name of launched script.
  echo "[${bldyell} WARN ${txtrst}] ${txtyell}${1:?'No Message provided...'}${txtrst}"
  f_log_write "[ WARN ] ${1:?'No Message provided...'}"
}
f_log_error() {
  f_log_caller_name # will setup CALLER_NAME var with the name of launched script.
  echo "[${bldred} CRIT ${txtrst}] ${txtred}${1:?'No Message provided...'}${txtrst}"
  f_log_write "[ CRIT ] ${1:?'No Message provided...'}"
}
f_log_caller_name() {
  SRC_SCRIPT_INDEX=$(( ${#BASH_SOURCE[@]} -1))
  SRC_SCRIPT_CALLER=${BASH_SOURCE[${SRC_SCRIPT_INDEX}]}
  SRC_SCRIPT_CALLER_NAME=$(basename ${SRC_SCRIPT_CALLER})
  unset SRC_SCRIPT_CALLER SRC_SCRIPT_INDEX
}
f_log_date() {
  date "+%Y-%m-%d %H:%M:%S"
}
f_log_write() {
  NO_LOGFILE=${NO_LOGFILE:-0}
  if [[ ! ${NO_LOGFILE^^} =~ ^(TRUE|ENABLED|YES|1)$ ]] ; then
      echo "$(f_log_date) ${1:?'No Message provided...'}" | tee -ai ${LOG_FOLDER}/${SRC_SCRIPT_CALLER_NAME}.${LOG_EXTEN} > /dev/null
  fi
}

### OPTIONAL ###

##############################################
# f_git_version_control
##############################################
#
# Used to put a directory under version control via git
#
f_git_version_control() {
  directory="${1}"
  git="/opt/tools/git/bin/git"

  cd "${directory}"
  if [[ -n $(${git} status --porcelain) ]] ; then
   ${git} add .
   ${git} commit -m "report saved $(date)"
  fi
  cd -
}

f_log_debug "$LIB_HOME/$LIB_NAME Loaded succesfully!"
