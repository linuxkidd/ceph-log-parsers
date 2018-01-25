#!/usr/bin/awk -f

###
#
# Pipe ceph.log into the script and redirect output to a CSV
# 
# cat ceph.log | ceph_log_parser.awk > ceph-log-parser.csv
#
# * For items which are average, these are summed and averaged over the measurement interval ( 10 minutes )
#   The measurement is reported at the beginning of the interval measurement period
#   e.g IO: Client Read MB/s for 03:30 to 03:40 is averaged, then reported on the 03:30 line
#
# * For items which are a static snapshot, these are reported based on the last line containing those
#   details in the log before the end of the measurement interval ( 10 minutes )
#   e.g. PG: active for 03:30 to 03:40 - If a pgmap is found at 03:39:59, that will be the one reported for
#        the 03:30 line
#
# * For items like the Slow requests, the count of those entries is summed during the 10 minute period and reported
#   e.g. If there are 50 'slow request ' logs in the 10 minute interval which are for a primary OSD, then 50 is reported
#        If there are 50 'slow request ' logs 'waiting for subop', then the OSDs called out by the subop (comma
#        separated numbers), are all counted in the 'Slow SubOp' line.  For 3x replication, and 50 lines, the reported 
#        number would be 100 (due to 2x non-primary copies * 50 lines)
#
#
###


function toMB(mynum,myunit) {
  myunit=tolower(myunit)
  if (myunit ~  /^b/) { mynum/=(1024*1024); }
  else if (myunit ~ /^kb/) { mynum/=1024; }
  else if (myunit ~ /^gb/) { mynum*=1024; }
  else if (myunit ~ /^tb/) { mynum*=1024*1024; }
  return sprintf("%0.2f",mynum)
}

function toTB(mynum,myunit) {
  myunit=tolower(myunit)
  if (myunit ~  /^b/) { mynum/=(1024*1024*1024*1024) }
  else if (myunit ~ /^kb/) { mynum/=(1024*1024*1024) }
  else if (myunit ~ /^mb/) { mynum/=(1024*1024) }
  else if (myunit ~ /^gb/) { mynum/=1024 }
  else if (myunit ~ /^pb/) { mynum*=1024 }
  else if (myunit ~ /^eb/) { mynum*=1024*1024 }
  return sprintf("%0.2f",mynum)
}

BEGIN {
  EVENTHEADERS["OSD Boot"]=1
  EVENTHEADERS["OSD Down: No PG stats"]=1
  EVENTHEADERS["OSD Down: Self"]=1
  EVENTHEADERS["OSD Down: Reported Failed"]=1
  EVENTHEADERS["OSD Out"]=1
  EVENTHEADERS["OSD Wrongly"]=1
  EVENTHEADERS["OSDs"]=1
  EVENTHEADERS["OSDs UP"]=1
  EVENTHEADERS["OSDs IN"]=1
  EVENTHEADERS["Slow Total"]=1
  EVENTHEADERS["Slow Primary"]=1
  EVENTHEADERS["Slow SubOp"]=1
}

/ pgmap / {
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  myline=$0
  myeventadd=0
  split(myline,mylineparts,";")

  for(linepartindex in mylineparts) {
    switch (mylineparts[linepartindex]) {
      case / pgs: /:
        split(mylineparts[linepartindex],junka,":")
        split(junka[7],pgstats,",")

        # Reset the counts so that only the last line in a measured interval is accumulated
        if(MYDTSTAMP in EVENTCOUNT) {
          for(key in EVENTCOUNT[MYDTSTAMP])
            if(key ~ /^PG: /)
              delete EVENTCOUNT[MYDTSTAMP][key]
        }

        for(pgstatindex in pgstats) {
          pgstat=pgstats[pgstatindex]
          split(pgstat,statparts," ")
          split(statparts[2],pgstate,"+")
          for(pgstateindex in pgstate) {
            myeventname="PG: "pgstate[pgstateindex]
            EVENTCOUNT[MYDTSTAMP][myeventname]+=statparts[1]
            EVENTHEADERS[myeventname]=1
          }
        }
        break
      case / avail$/:
        split(mylineparts[linepartindex],clusterspace,",")
        for(spaceindex in clusterspace) {
          split(clusterspace[spaceindex],myspaceparts," ")
          if(myspaceparts[3] ~ /^data/) {
            EVENTCOUNT[MYDTSTAMP]["Space (TB): Data Stored"]=toTB(myspaceparts[1],myspaceparts[2])
            EVENTHEADERS["Space (TB): Data Stored"]=1
          } else if(myspaceparts[3] ~ /^used/) {
            EVENTCOUNT[MYDTSTAMP]["Space (TB): Raw Used"]=toTB(myspaceparts[1],myspaceparts[2])
            EVENTHEADERS["Space (TB): Raw Used"]=1
          } else if(6 in myspaceparts) {
            EVENTCOUNT[MYDTSTAMP]["Space (TB): Free"]=toTB(myspaceparts[1],myspaceparts[2])
            EVENTCOUNT[MYDTSTAMP]["Space (TB): Total"]=toTB(myspaceparts[4],myspaceparts[5])
            EVENTHEADERS["Space (TB): Free"]=1
            EVENTHEADERS["Space (TB): Total"]=1
          }
        }
        break
      case /op\/s/:
        split(mylineparts[linepartindex],clilineparts,",")
        for(clilpindex in clilineparts) {
          split(clilineparts[clilpindex],mycliparts," ")
          if(3 in mycliparts) {
            myeventadd=toMB(mycliparts[1],mycliparts[2])
            if(mycliparts[3] ~ /^rd/) {
              myeventname="IO: Client Avg Read MB/s"
              myeventcount="Client Read Count"
            }
            else if(mycliparts[3] ~ /^wr/) {
              myeventname="IO: Client Avg Write MB/s"
              myeventcount="Client Write Count"
            }
          } else {
              myeventname="IO: Client Avg IOPs"
              myeventadd=mycliparts[1]
              myeventcount="Client IOPsCount"
          }
          EVENTHEADERS[myeventname]=1
          EVENTCOUNT[MYDTSTAMP][myeventname]=sprintf("%0.2f",((EVENTCOUNT[MYDTSTAMP][myeventname]*EVENTCOUNT[MYDTSTAMP][myeventcount])+myeventadd)/(EVENTCOUNT[MYDTSTAMP][myeventcount]+1))
          EVENTCOUNT[MYDTSTAMP][myeventcount]++
        }
        break
      case / objects degraded /:
        split(mylineparts[linepartindex],degradeobj," ")
        gsub(/[^0-9\.]/,"",degradeobj[4])
        EVENTCOUNT[MYDTSTAMP]["Objects: Degraded Percent"]=degradeobj[4]
        EVENTHEADERS["Objects: Degraded Percent"]=1
        break
      case / objects misplaced /:
        split(mylineparts[linepartindex],degradeobj," ")
        gsub(/[^0-9\.]/,"",degradeobj[4])
        EVENTCOUNT[MYDTSTAMP]["Objects: Misplaced Percent"]=degradeobj[4]
        EVENTHEADERS["Objects: Misplaced Percent"]=1
        break
      case / recovering$/:
        myeventname="IO: Recovery Avg MB/s"
        myeventcount="RecoveryCount"
        split(mylineparts[linepartindex],reclineparts," ")
        reclineparts[1]=toMB(reclineparts[1],reclineparts[2])
        EVENTCOUNT[MYDTSTAMP][myeventname]=sprintf("%0.2f",((EVENTCOUNT[MYDTSTAMP][myeventname]*EVENTCOUNT[MYDTSTAMP][myeventcount])+myeventadd)/(EVENTCOUNT[MYDTSTAMP][myeventcount]+1))
        EVENTCOUNT[MYDTSTAMP][myeventcount]++
        EVENTHEADERS[myeventname]=1
        break
    }
  }
}

/ deep-scrub / {
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  MYPG=$9
  MYDATE=$1
  MYTIME=$2
  gsub(/[-:]/," ",MYDATE)
  gsub(/[-:]/," ",MYTIME)
  MYTIME=mktime(MYDATE" "MYTIME)
  split($2,secs,".")
  millisecs=sprintf("0.%s",secs[2])
  MYTIME+=millisecs

  if($NF == "starts") {
    EVENTCOUNT[MYDTSTAMP]["Deep-Scrub: Starts"]++
    EVENTHEADERS["Deep-Scrub: Starts"]=1
    OSDEVENT[$3]["Deep-Scrub: Starts"]++
    EVENTTOTAL["Deep-Scrub: Starts"]++
    MYSTART[MYPG]=MYTIME
  }
  else {
    if(MYSTART[MYPG]!="") {
      mydiff=MYTIME-MYSTART[MYPG]
      split(MYPG,pgparts,".")
      POOLSCRUBS[pgparts[1]]["Count"]++
      POOLSCRUBS[pgparts[1]]["Sum"]+=mydiff
      if(mydiff>POOLSCRUBS[pgparts[1]]["Max"] || POOLSCRUBS[pgparts[1]]["Max"] == "")
        POOLSCRUBS[pgparts[1]]["Max"]=mydiff
      if(mydiff<POOLSCRUBS[pgparts[1]]["Min"] || POOLSCRUBS[pgparts[1]]["Min"] == "")
        POOLSCRUBS[pgparts[1]]["Min"]=mydiff
    }
    if($NF == "ok") {
      EVENTCOUNT[MYDTSTAMP]["Deep-Scrub: OK"]++
      EVENTHEADERS["Deep-Scrub: OK"]=1
      EVENTTOTAL["Deep-Scrub: OK"]++
      OSDEVENT[$3]["Deep-Scrub: OK"]++
    } else {
      EVENTCOUNT[MYDTSTAMP]["Deep-Scrub: Not OK"]++
      EVENTHEADERS["Deep-Scrub: Not OK"]=1
      EVENTTOTAL["Deep-Scrub: Not OK"]++
      OSDEVENT[$3]["Deep-Scrub: Not OK"]++
    }
  }
}

/slow request / {
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP]["Slow Total"]++
  if ($0 ~ /subops from/) {
    split($NF,subosds,",")
    for (subosd in subosds) {
      subosd="osd."subosd
      OSDEVENT[subosd]["Slow Total"]++
      EVENTTOTAL["Slow Total"]++
      OSDEVENT[subosd]["Slow SubOp"]++
      EVENTTOTAL["Slow SubOp"]++
      EVENTCOUNT[MYDTSTAMP]["Slow SubOp"]++
    }
  } else {
    EVENTCOUNT[MYDTSTAMP]["Slow Primary"]++
    OSDEVENT[$3]["Slow Primary"]++
    EVENTTOTAL["Slow Primary"]++
    OSDEVENT[$3]["Slow Total"]++
    EVENTTOTAL["Slow Total"]++
    MYTYPE=$0
    gsub(/^.* currently /,"Slow Primary: ",MYTYPE)
    OSDEVENT[$3][MYTYPE]++
    EVENTTOTAL[MYTYPE]++
    EVENTHEADERS[MYTYPE]=1
    EVENTCOUNT[MYDTSTAMP][MYTYPE]++
  }
}

/ osdmap / {
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP]["OSDs"]=$11
  EVENTCOUNT[MYDTSTAMP]["OSDs UP"]=$13
  EVENTCOUNT[MYDTSTAMP]["OSDs IN"]=$15
}

/ osd\.[0-9]* out / {
  MYEVENT="OSD Out"
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP][MYEVENT]++
  EVENTTOTAL[MYEVENT]++
  OSDEVENT[$9][MYEVENT]++
}

/ wrongly marked me down$/ {
  MYEVENT="OSD Wrongly"
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP][MYEVENT]++
  EVENTTOTAL[MYEVENT]++
  OSDEVENT[$3][MYEVENT]++
}

/ marked itself down / {
  MYEVENT="OSD Down: Self"
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP][MYEVENT]++
  EVENTTOTAL[MYEVENT]++
  OSDEVENT[$9][MYEVENT]++
}

/ failed .*reports from / {
  MYEVENT="OSD Down: Reported Failed"
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP][MYEVENT]++
  EVENTTOTAL[MYEVENT]++
  OSDEVENT[$9][MYEVENT]++
}

/ marked down after no pg stats for / {
  MYEVENT="OSD Down: No PG stats"
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP][MYEVENT]++
  EVENTTOTAL[MYEVENT]++
  OSDEVENT[$9][MYEVENT]++
}

/ boot$/ {
  MYEVENT="OSD Boot"
  MYDTSTAMP=sprintf("%s %s0",$1,substr($2,1,4))
  EVENTCOUNT[MYDTSTAMP][MYEVENT]++
  EVENTTOTAL[MYEVENT]++
  OSDEVENT[$9][MYEVENT]++
}

END {
  printf("DateTime")
  n=asorti(EVENTHEADERS)
  for (i = 1; i<= n; i++ ) {
    printf(",%s",EVENTHEADERS[i])
  }
  printf("\n")

  dtcount=asorti(EVENTCOUNT,DTS)

  for (dtindex =1; dtindex <= dtcount; dtindex++) {
    DT=DTS[dtindex]
    printf("%s:00", DT)
    for (i = 1; i<= n; i++ ) {
      printf(",%s",EVENTCOUNT[DT][EVENTHEADERS[i]])
    }
    printf("\n")
  }
  printf("Totals")
  for (i = 1; i<= n; i++ ) {
    printf(",%s",EVENTTOTAL[EVENTHEADERS[i]])
  }
  printf("\n")
  printf("\n")

  printf("osd.id")
  for (i = 1; i<= n; i++ ) {
    printf(",%s",EVENTHEADERS[i])
  }
  printf("\n")

  for (OSD in OSDEVENT) {
    gsub(/^osd\./,"",OSD)
    OSDS[OSD]=OSD
  }
  osdcount=asort(OSDS)

  for (osdindex=1; osdindex<=osdcount; osdindex++) {
    osd="osd."OSDS[osdindex]
    printf("%s",osd)
    for (i = 1; i<= n; i++ ) {
      printf(",%s",OSDEVENT[osd][EVENTHEADERS[i]])
    }
    printf("\n")
  }
  printf("Totals")
  for (i = 1; i<= n; i++ ) {
    printf(",%s",EVENTTOTAL[EVENTHEADERS[i]])
  }
  printf("\n\n")
  poolcount=asorti(POOLSCRUBS,poolids)

  print "Pool ID,Deep Scrub Count,Deep-Scrub Time (Sec): Min,Deep-Scrub Time (Sec): Avg,Deep-Scrub Time (Sec): Max,Deep-Scrub Time(Sec): Total"
  for(pindex=1;pindex<=poolcount;pindex++)
    printf("%d,%d,%0.7f,%0.7f,%0.7f,%0.7f\n",poolids[pindex],POOLSCRUBS[poolids[pindex]]["Count"], POOLSCRUBS[poolids[pindex]]["Min"],POOLSCRUBS[poolids[pindex]]["Sum"]/POOLSCRUBS[poolids[pindex]]["Count"],POOLSCRUBS[poolids[pindex]]["Max"],POOLSCRUBS[poolids[pindex]]["Sum"])
}
