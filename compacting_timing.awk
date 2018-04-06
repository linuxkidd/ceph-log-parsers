#!/usr/bin/awk -f

##
## Provide an OSD log for timing output of each leveldb Compaction event
## ./compacting_timing.awk ceph-osd.10.log
##
##

BEGIN {
  begtime=0
  endtime=0
}
/leveldb: Compact/ {
  MYLINE=$0
  gsub(/[-:]/," ",$1)
  gsub(/[-:]/," ",$2)
  MYTIME=mktime($1" "$2)
  split($2,secs,".")
  millisecs=sprintf("0.%s",secs[2])
  MYTIME+=millisecs

  if(begtime==0) {
    begtime=MYTIME
  }
  if(MYTIME>endtime) {
    endtime=MYTIME
  }
  if($6=="Compacting") {
    MYSTART=MYTIME
    next
  }

  if(MYSTART!="") {
    mydiff=MYTIME-MYSTART
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
    MYSTART=""
  }
}
END {
  if(mycount=="")
    mycount=1
  printf("Min,Avg,Max,Total Time Spent,%Time spent in compaction\n%s,%s,%s,%s,%s\nMin Req: %s\nMax Req: %s\n",mymin,mysum/mycount,mymax,mysum,mysum/(endtime-begtime)*100,myminreq,mymaxreq)
}
