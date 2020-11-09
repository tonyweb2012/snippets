#!/usr/bin/env bash

netgroup=${1:-}

netgroup_users="$(getent netgroup ${netgroup} | tee /dev/tty)"

#echo "getent netgroup ${netgroup} => ${netgroup_users}"
echo ${netgroup_users} | sed -r 's/(^.[^ ]+)\s*(.*)/User_Alias \1 = \2/' | sed 's/,) ( ,/, /g' | sed 's/( ,\|,)//g'

# useful to "convert" a netgroup with users into a User_Alias for sudoers file.
