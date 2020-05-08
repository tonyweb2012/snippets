#!/usr/bin/env bash

while read -p "Do you want to continue [y/n]?" rep; do
case "${rep}" in
Y|y) echo "Go again"
echo "let's run this shit"
break
;;
N|n) echo "Bye... Process aborted"
break
;;
*) echo "Excuse me?"
;;
esac
done
