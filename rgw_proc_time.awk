#!/usr/bin/awk -f
BEGIN {
  MYMONTHS["Jan"]=1
  MYMONTHS["Feb"]=2
  MYMONTHS["Mar"]=3
  MYMONTHS["Apr"]=4
  MYMONTHS["May"]=5
  MYMONTHS["Jun"]=6
  MYMONTHS["Jul"]=7
  MYMONTHS["Aug"]=8
  MYMONTHS["Sep"]=9
  MYMONTHS["Oct"]=10
  MYMONTHS["Nov"]=11
  MYMONTHS["Dec"]=12
}

{
  gsub(/[-:]/," ",$1)
  gsub(/[-:]/," ",$2)
  ENDTIME=mktime($1" "$2)
  split($2,secs,".")
  millisecs=sprintf("0.%s",secs[2])
  ENDTIME+=millisecs

  sub(/^./,"",$10)
  gsub(/[\/\-:]/," ",$10)
  maxb=split($10,b," ")
  b[2]=sprintf("%02d",MYMONTHS[b[2]])
  STARTTIMESTRING=b[3]" "b[2]" "b[1]" "b[4]" "b[5]" "b[6]
  STARTTIME=mktime(STARTTIMESTRING)
  delta=ENDTIME-STARTTIME
  print $1" "$2" ("ENDTIME") -"STARTTIMESTRING" ("STARTTIME") :: "delta
}
