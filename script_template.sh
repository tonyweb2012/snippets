#!/usr/bin/env bash

######################################################################################################################
# Environment
######################################################################################################################

MY_NAME="$(basename "$(realpath "$0")")"                                # Name of the script, without the path
MY_HOME="$(dirname "$(realpath "$0")")"                                 # Base working directory

######################################################################################################################
# Lib sourcing
######################################################################################################################
# Source libraries files. Use dot instead of source for compatibility purposes
if ! . /path/to/lib/functions/file ; then
    echo "Something went wrong while parsing lib file. Exiting!"
    exit 254
fi

# The library provide a few functions, like external script relative path. Please use it instead of direct calls.
#  _purpose_
#    It also provide host file full path, and some functions like logging.
#  _logging_
#    There are 4 logging functions: f_log_error , f_log_warn and f_log_info are displayed on screen and outputed to log file (auto generated)
#    The f_log_debug function only display if DEBUG=true but never to log files.
#  _errors_
#    To enable strict error handling, just call
error_set
#    function. If you defined a `exit_custom` it will be called automaticaly.

mode=""
db=""
ssh="ssh -oBatchMode=yes -oConnectTimeout=5 -oPasswordAuthentication=no"
scp="scp -oConnectTimeout=5 -oPasswordAuthentication=no -p"

######################################################################################################################
# Functions
######################################################################################################################

##############################################
# f_parse_args: parse arguments provided to the script
##############################################
f_parse_args() {
  # Usage if no args
  (( $# == 0 )) && f_usage

  # Parsing args
  while getopts "m:d:D" opt; do
    case $opt in
      m)
      mode="$OPTARG"
      ;;
      d)
      db="$OPTARG"
      ;;
      D)
      # xtrace output containing source file and line number.
      export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
      set -o xtrace
      ;;
      :)
      exit 1
      ;;
      \?)
      exit 1
      ;;
    esac

    if [[ ${OPTARG:-unset} != "unset" ]] ; then
      if [[ ${OPTARG-unset} =~ '^-[[:alpha:]]{1}$' ]] ; then
        echo  "[${bldred} ERROR ${txtrst}] you passed ${OPTARG} as an argument of the -${opt} options"
        f_usage
      fi
    fi
  done

  #/************************************************************
  #*                    DO YOUR CHECK HERE                     *
  #************************************************************/
  echo  "[${bldred} ERROR ${txtrst}] do your parse arguments here ! mode=${mode} ; db = ${db}"
  f_usage
}

##############################################
# f_usage
##############################################
f_usage() {
  cat <<EOU

  FILL the USAGE !!!

EOU
  exit
}

##############################################
# f_backup_files TODO
##############################################
#
# Please, if you have to edit files, you must make an atomic modification than editing files in place
#
# http://www.davidpashley.com/articles/writing-robust-shell-scripts/
#
f_backup_files() {
  # always use mktemp to avoid possible conflict
  # if its remotely, a good practice is to create a temp directory like :
  #
  # _backup_dir_=$(${ssh} USER@HOST "mktemp -d /path/filename_XXXXXXX")
  #
  # Otherwise, the "backup" alias should be sufficient
  f_log_error "backup_files !!! -- please fill this function"
}

##############################################
# traps
##############################################
exit_custom() {
  save_err=$?
  save_cmd=$BASH_COMMAND
  if [[ ${save_err} -ne 0 ]] ; then
    # check that f_log_error is defined before calling it
    if [[ $(type -t f_log_error) == "function" ]] ; then
      f_log_error "Command ${save_cmd} exited with code ${save_err}"
    else # otherwise, copy the content of f_log_error here
      echo "[${bldred:-} CRIT ${txtrst:-}] ${1:?'No Message provided...'}"
      echo -e "${start_time:-} ${script_name:-} $$ [CRIT] : $1" \
      | sed -r "s:\x1b\[[0-9;]*[mK@]::g" >> "${logfile_path}/${logfile_name}"
    fi
  fi
}


######################################################################################################################
# MAIN
######################################################################################################################

f_parse_args "$@"

#case ${mode} in
#  "batch")
#  ;;
#esac
