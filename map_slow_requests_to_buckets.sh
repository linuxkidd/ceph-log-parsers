#!/bin/bash

if [ -z $2 ]; then
	echo
	echo "Usage: $(basename $0) <ceph.log> <osd-tree>"
	echo
	exit 1
fi

if [ ! -e $1 ]; then
	echo "File $1 does not exist."
fi

if [ ! -e $2 ]; then 
	echo "File $2 does not exist."
fi

slowfile=$(mktemp)

## Generate list of slow OSDs ( column 3 if non-subop, or last column split on comma if subop )
awk '/slow request / { if ( $NF ~ /,/ ) { split($NF,a,","); for (i in a) { printf("osd.%s\n", a[i]) } } else { print $3}}' $1 | sort -n | uniq -c > $slowfile

buckets=()
currbuckets=()
inhost=0
depth_count=0
bucket_counts=()

while read line; do
	thirdcol=$(echo $line | awk '{print $3}')
	forthcol=$(echo $line | awk '{print $4}')
	if [ $thirdcol == "Type" -o $thirdcol == "TYPE" ]; then
		continue
	fi
	if [ $(echo $thirdcol | grep -c ^osd\.) -gt 0 ]; then
		## Found an OSD
		slow_count=$(awk -v p="$thirdcol" '{if ( $2 == p ) { print $1 }}' $slowfile)
		if [ -z $slow_count ]; then slow_count=0; fi

		for ((i = 0; i < ${#buckets[*]} ; i++)) {
			bucket=${buckets[$i]}
			((bucket_counts[$i]+=$slow_count))
			echo -n "${!bucket},"
		}
		((bucket_counts[$i]+=$slow_count))
		echo "$thirdcol,$slow_count"
	else
		havebucket=-1
		for ((i = 0; i < ${#buckets[*]} ; i++)) {
			if [ ${buckets[$i]} == $thirdcol ]; then
				havebucket=$i
			fi
		}
		if [ $havebucket -eq -1 ]; then
			buckets+=($thirdcol)
			((i++))
			bucket_counts[$i]=0
		else
			highest_bucket=${#buckets[*]}
			for ((j = $highest_bucket; j > $havebucket; j--)) {
				for ((i = 0; i < $j ; i++)); do
					bucket=${buckets[$i]}
					echo -n "${!bucket},"
				done
				echo ${bucket_counts[$j]}
				bucket_counts[j]=0
				if [ $j -gt $(($havebucket+1)) ]; then
					unset buckets[${#buckets[*]}-1]
				fi
			}
		fi
		declare "${thirdcol}=${forthcol}"
	fi
done < $2
highest_bucket=${#buckets[*]}
for ((j = $highest_bucket; j > 0; j--)) {
	for ((i = 0; i < $j ; i++)); do
		bucket=${buckets[$i]}
		echo -n "${!bucket},"
	done
	echo ${bucket_counts[$j]}
	bucket_counts[j]=0
}

rm -f $slowfile