#!/bin/bash

awk 'BEGIN {
   mymin=999
   mymax=0
   mysum=0
   mycount=0
  }
  /starting new request/ {
   MYREQ=$9
   MYLINE=$0
   gsub(/[-:]/," ",$1)
   gsub(/[-:]/," ",$2)
   MYSTART[MYREQ]=mktime($1" "$2)
   split($2,secs,".")
   millisecs=sprintf("0.%s",secs[2])
   MYSTART[MYREQ]+=millisecs
  }
  /req done/ {
   MYLINE=$0;
   if(MYSTART[$8]!="") {
     gsub(/[-:]/," ",$1)
     gsub(/[-:]/," ",$2)
     MYSTOP=mktime($1" "$2)
     split($2,secs,".")
     millisecs=sprintf("0.%s",secs[2])
     MYSTOP+=millisecs
     mydiff=MYSTOP-MYSTART[$8]
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
