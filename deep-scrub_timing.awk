#!/usr/bin/awk -f

###
#
# Pipe a 'ceph.log' file into the script, redirect the output to a .csv file
#
# cat ceph.log | deep-scrub_histo.awk > deep-scrub_histo.awk
#
###


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
    MYSTART[MYPG]=MYTIME
    next
  }

  if(MYSTART[MYPG]!="") {
    mydiff=MYTIME-MYSTART[MYPG]
    if(mydiff<mymin || mymin=="") {
      myminreq=MYLINE
      mymin=mydiff
    }
    if(mydiff>mymax || mymin=="") {
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
}
