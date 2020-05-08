

START=$(date +%s)




END=$(date +%s)
DIFF=$(( $END - $START ))
DIFF=$(( $DIFF / 60 ))

# $DIFF will give you the runtime of the script in minutes.
