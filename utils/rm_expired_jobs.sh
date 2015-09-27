#!/bin/bash
#
# This script is intended to be used with the cron utility.
#

DATA_DIR=$1              # data directory with PIQMIe jobs
JOBS_FILE=$2             # text file with jobIDs to be kept
EXPIRE_TIME=$((24*60*7)) # check data directory once per week (in minutes)
USAGE="$0 [DATA DIR] [JOBS FILE]"

if [ $# -eq 2 ] && [ -d $DATA_DIR ] && [ -f $JOBS_FILE ] ; then
   # remove expired jobs
   echo "Remove jobs in the '$DATA_DIR' directory."

   find $DATA_DIR -mindepth 1 -mmin +$EXPIRE_TIME |\
   grep -v -f $JOBS_FILE |\
   xargs rm -fr
else
   echo $USAGE
   exit 1
fi
