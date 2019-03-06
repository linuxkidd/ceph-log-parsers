#!/usr/bin/awk -f

###
#
# Pipe a 'ceph.log' file into the script, redirect the output to a .csv file
#
# cat ceph.log | deep-scrub_histo.awk > deep-scrub_histo.csv
#
# Added ability to map acting OSDs to the PG scrub line
#
# Example:
# cat ceph.log | deep-scrub_histo.awk -v pgdump=/path/to/pgdump > deep-scrub_histo.csv
#
###

function safediv(a,b) {
  if(b==0) {
    return 0
  } else {
    return a/b
  }
}

BEGIN {
  if(pgdump != "") {
    while(( getline line<pgdump ) > 0) {
      split(line,a," ")
      if(a[1] ~ /[0-9]*\.[0-9a-f]*/)
        gsub(/[\[\]]/, "", a[15])
        gsub(/,/, ",osd.", a[15])
        PGsToOSD[a[1]]="osd."a[15]
    }
  }
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
    printf("%s,%s,%s\n", mydiff,PGsToOSD[MYPG],MYLINE)
  }
}
END {
  printf("Min,Avg,Max\n%s,%s,%s\nMin Req: %s\nMax Req: %s\n",mymin,safediv(mysum,mycount),mymax,myminreq,mymaxreq)
}
