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

counters="prim subop rwlock slow fail boot wrong"

declare -A files
declare -A bucket_counts
declare -A local_count
for j in $counters; do
	files[$j]=$(mktemp)
done

## Generate list of slow OSDs ( column 3 if non-subop, or last column split on comma if subop )
echo -n "Searching for... slow" >&2
awk '/slow request / { if ( $NF !~ /,/) { print $3}}' $1 | sort -n | uniq -c > ${files['prim']}
echo -n ", subops" >&2
awk '/slow request / { if ( $NF ~ /,/ ) { split($NF,a,","); for (i in a) { printf("osd.%s\n", a[i]) } }}' $1 | sort -n | uniq -c > ${files['subop']}
echo -n ", rwlock" >&2
grep 'slow request ' $1 | grep 'currently waiting for rw locks' | awk '{print $3}' | sort -n | uniq -c > ${files['rwlock']}

## Generate list of failed,booted and wrongly marked me down OSDs 
echo -n ", failed" >&2
awk '/ failed / {print $9}' $1 | sort -n | uniq -c > ${files['fail']}
echo -n ", boot" >&2
awk '/ boot$/ {print $9}' $1 | sort -n | uniq -c > ${files['boot']}
echo -n ", wrongly marked down" >&2
awk '/ wrongly marked me down$/ {print $3}' $1 | sort -n | uniq -c > ${files['wrong']}
echo  >&2


buckets=()
currbuckets=()
inhost=0
depth_count=0

echo "buckets...,slow primary,slow subop,rwlock, total slow,failed,boot,wrongly down"

while read line; do  ## Read in line by line of the OSD Tree
	thirdcol=$(echo $line | awk '{print $3}')  ## Get the 3rd Column
	forthcol=$(echo $line | awk '{print $4}')  ## Get the 4th Column
	if [ $(echo $thirdcol | grep -ic "^type$") -gt 0 ]; then  ## If the 3rd Column == type (in any case), then it's a header, skip it
		continue
	fi
	if [ $(echo $thirdcol | grep -c ^osd\.) -gt 0 ]; then    ## If the 3rd Column starts with 'osd.', then let's process it
		## Found an OSD

		for j in $counters; do	## Grab a value from the temp files for each counter type for this current OSD -- counters declared toward beginning of script
			if [ $j != 'slow' ]; then
				local_count[$j]=$(awk -v p="$thirdcol" '{if ( $2 == p ) { print $1 }}' ${files[$j]})
				if [ -z ${local_count[$j]} ]; then  ## If the value is blank, then make it 0
					local_count[$j]=0
				fi
			else
				local_count[$j]=$((${local_count['prim']}+${local_count['subop']}))
			fi
		done

		for ((i = 0; i < ${#buckets[*]} ; i++)) {  ## For each level of bucket above our current position (rack, row, root, etc), add the current counters to that buckets above us.
			bucket=${buckets[$i]}
			for j in $counters; do
				((bucket_counts[$j,$i]+=${local_count[$j]}))  ## Ya, bash does math funkily, and doesn't really do multi-dimentional arrays.  This is a hack.
			done
			echo -n "${!bucket},"  ## Echo the bucket names above where we are right now ( root,rack,hostname,etc )
		}
		echo -n "$thirdcol"  ## Echo the OSD name ( osd.# )
		for j in $counters; do  ## For each counter
			((bucket_counts[$j,$i]+=${local_count[$j]}))  ## , append the current value to the host bucket
			echo -n ,${local_count[$j]}   ## , and write the value to output
		done
		echo    ## Wrap the output line
	else
		havebucket=-1   ## Set flag indicating we don't know about this bucket yet
		for ((i = 0; i < ${#buckets[*]} ; i++)) {  ## Search through the list of buckets
			if [ ${buckets[$i]} == $thirdcol ]; then  ## If we find the same bucket bucket type (likely another host, but maybe we hit a new rack, root, etc)
				havebucket=$i                     ## Set the flag indicating we found it, and where
			fi
		}
		if [ $havebucket -eq -1 ]; then  ## If we did NOT find the bucket type
			buckets+=($thirdcol)     ## Append the bucket type to the 'buckets' array
			((i++))                  ## Increment the positional variable from the last loop
			for j in $counters; do   ## For each counter, set the new buckets counters to 0
				bucket_counts[$j,$i]=0
			done
		else                             ## We DID find the bucket!
			highest_bucket=${#buckets[*]}
			for ((k = $highest_bucket; k > $havebucket; k--)) {  ## Step from the highest_bucket level, backwards to the current buckets index
				for ((i = 0; i < $k ; i++)); do              ## For each bucket type before the current highest level,
					bucket=${buckets[$i]}                ## Output the bucket names to make an output line for cumulative values
					echo -n "${!bucket},"                ## This is substituting a variable for a variable name ( e.g. echo $host, or echo $rack )
				done
				for j in $counters; do
					echo -n ${bucket_counts[$j,$k]},     ## and output those cumulative values for this level (e.g. host level, rack level, etc.. as we're stepping backwards
					bucket_counts[$j,$k]=0               ## And reset the counter value back to 0 for this bucket type (we will likely re-use it, host bucket type for example)
				done
				echo    ## Wrap the output line
				if [ $k -gt $(($havebucket+1)) ]; then
					unset buckets[${#buckets[*]}-1]
				fi
			}
		fi
		declare "${thirdcol}=${forthcol}"
	fi
done < $2
highest_bucket=${#buckets[*]}
for ((k = $highest_bucket; k > 0; k--)) {
	for ((i = 0; i < $k ; i++)); do
		bucket=${buckets[$i]}
		echo -n "${!bucket},"
	done
	for j in $counters; do
		echo -n ${bucket_counts[$j,$k]},
		bucket_counts[$j,$k]=0
		rm -f $files[$j]
	done
	echo
}
