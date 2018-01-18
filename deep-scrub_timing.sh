#!/bin/bash

if [ -z $1 ]; then
	echo
	echo "Usage: $(basename $0) <ceph.log>"
	echo
	exit 1
fi

if [ ! -e $1 ]; then
	echo "File $1 does not exist."
fi

awk 'BEGIN {
   mymin=999
   mymax=0
   mysum=0
   mycount=0
  }
  /deep-scrub/ {
   MYLINE=$0
   MYPG=$9
   gsub(/[-:]/," ",$1)
   gsub(/[-:]/," ",$2)
   MYTIME=mktime($1" "$2)
   split($2,secs,".")
   millisecs=sprintf("0.%s",secs[2])
   MYTIME+=millisecs

   if($NF=="starts") {
     MYSTART[MYPG]+=MYTIME
     next
   }
    
   if(MYSTART[MYPG]!="") {
     mydiff=MYTIME-MYSTART[MYPG]
     if(mydiff<mymin) {
       myminreq=MYLINE
       mymin=mydiff
     }
     if(mydiff>mymax) {
       mymaxreq=MYLINE
       mymax=mydiff
     }
     mysum+=mydiff
     mycount++
     printf("%s,%s\n", mydiff, MYLINE)
   }
 }
 END {
   printf("Min,Avg,Max\n%s,%s,%s\nMin Req: %s\nMax Req: %s\n",mymin,mysum/mycount,mymax,myminreq,mymaxreq)
 }' $1
