#!/bin/bash

if [ -z $1 ] ; then
	echo
	echo '	Usage:'
	echo
	echo "		$(basename $0) {ceph.log}"
	echo
	exit 1
fi

echo xThousand,Count

grep pgmap $1 | awk -F\; '{split($3,a," "); print int(a[7]/1000) }' | sort -n | grep . | uniq -c | awk '{print $2","$1}'
