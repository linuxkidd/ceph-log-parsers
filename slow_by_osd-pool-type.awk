#!/usr/bin/awk -f
#
# by: Michael Kidd
# https://github.com/linuxkidd
#
# Use:
#   chmod 755 slow_by_osd-pool-type.awk
#   ./slow_by_osd-pool-type.awk ceph.log
#
# Output Options:
#   -v csv=1
#   -v pivot=1
#   -v perline=1
#
# Note: with no '-v' option specified, it provides 'visual' output for easy human parsing
# Note2: Only one output option may be used per execution
#
#

BEGIN {
  PROCINFO["sorted_in"] = "@val_num_asc"
}

/slow request [3-5][0-9]\./ {
  if($20 ~ /^[0-9]*\.[0-9a-fs]*$/) {
    split($20,a,".")
    b=$0
    gsub(/^.*currently /,"",b)
    gsub(/ from .*/, "", b)
    slowtype[b]++
    slowosd[$3]++
    slowosdbytype[$3][b]++
    slowbypool[a[1]]++
    slowbypooltype[a[1]][b]++
    slowpoolosdtype[a[1]][$3][b]++
    slowtypepools[b][a[1]]++
  }
}

function printVisual() {
  print "Pool stats: "
  for(p in slowbypool) {
    print "Pool id: "p" Total slow: "slowbypool[p]
    for (t in slowbypooltype[p]) {
      print "\t"slowbypooltype[p][t]"\t"t
    }
  }
  print ""
  print ""
  print "OSD Stats: "
  for (o in slowosd) {
    print "\t"o" "slowosd[o]
    for (t in slowosdbytype[o]) {
      print "\t\t"slowosdbytype[o][t]" "t
    }
  }
  print ""
  print ""
  print "Slow by Type: "
  for (t in slowtype) {
    print "\t"slowtype[t]" "t
  }
}

function printCSV() {
  printf("Pool,")
  for(t in slowtype) {
    printf("%s,",t)
  }
  print ""
  for(p in slowbypool) {
    printf("%s,",p)
    for (t in slowtype) {
      printf("%d,",slowbypooltype[p][t])
    }
    print ""
  }
  printf("Total:,")
  for (t in slowtype) {
    printf("%d,",slowtype[t])
  }
  print ""
  print ""
  printf("OSD,")
  for(t in slowtype) {
    printf("%s,",t)
  }
  print ""
  for (o in slowosd) {
    printf("%s,",o)
    for (t in slowtype) {
      printf("%s,",slowosdbytype[o][t])
    }
    print ""
  }
  printf("Total:,")
  for (t in slowtype) {
    printf("%d,",slowtype[t])
  }
  print ""
}

function printPerLine() {
  print "Pool,OSD,Type,Count"
  for(p in slowpoolosdtype){
    for(o in slowpoolosdtype[p]) {
      for(t in slowpoolosdtype[p][o])
        print p","o","t","slowpoolosdtype[p][o][t]
    }
  }
}

function printPivot() {
  printf(",")
  for(t in slowtype) {
    printf("%s",t)
    for(p in slowtypepools[t]) {
      l2=l2","p
      ptotal=ptotal","slowtypepools[t][p]
      sumtotal+=slowtypepools[t][p]
      printf(",")
    }
  }
  print "Totals"
  printf("OSD / Pool ID%s\n",l2)
  for(o in slowosd) {
    printf("%s,",o)
    for(t in slowtype) {
      for(p in slowtypepools[t]) {
        if(slowpoolosdtype[p][o][t]>0)
          printf("%d,",slowpoolosdtype[p][o][t])
        else
          printf(",")
      }
    }
    print slowosd[o]
  }
  print "Totals:"ptotal","sumtotal
}

END {
  if(csv==1)
    printCSV()
  else if(pivot==1)
    printPivot()
  else if(perline==1)
    printPerLine()
  else
    printVisual()
}

