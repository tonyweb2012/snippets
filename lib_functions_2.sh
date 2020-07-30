#!/usr/bin/env bash

ssh='ssh -o StrictHostKeyChecking=no -oBatchMode=yes -oConnectTimeout=3 '

# check and echo Open or Closed against a IP/hostname and port
# inputs: source host + target IP or hostname + port
f_check_vault_reachable() {
   local my_host=$1 my_target=$2 my_port=$3
   #echo "Running ${FUNCNAME[0]}"
   if [[ -z ${my_host} || -z ${my_target} || ! "${my_port}" =~ ^[0-9]+$ ]]; then
      echo "Incorrect parameter(s) provided. Please check!"
      echo "host: ${my_host} - target: ${my_target} - port: ${my_port}"
      return 1
   fi
   #if ${ssh} "${my_host}" "timeout 1 bash -c '(>/dev/tcp/${my_target}/${my_port} &>/dev/null)'" ; then
   if ${ssh} "${my_host}" ">/dev/tcp/${my_target}/${my_port} &>/dev/null" &>/dev/null ; then
      echo "${my_host} to ${my_target}:${my_port} : Open"
   else
      echo "${my_host} to ${my_target}:${my_port} : Closed"
   fi
   return 0
}


# check ping and SSH against a host
f_check_host_reachability() {
   local hostname=${1:-}
   if ping -c1 ${hostname} &>/dev/null ; then
      if ${ssh} "${hostname}" ":" &>/dev/null ; then
         return 0
      else
         echo "Unable to SSH to ${hostname} or connection too slow!"
      fi
   else
      echo "Cannot ping to ${hostname}"
   fi
   return 1
}
