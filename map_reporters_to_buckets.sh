#!/bin/bash

if [ -z $2 ]; then
	echo
	echo "Usage: $(basename $0) <ceph-mon.log> <osd-tree>"
	echo
	exit 1
fi

if [ ! -e $1 ]; then
	echo "File $1 does not exist."
fi

if [ ! -e $2 ]; then 
	echo "File $2 does not exist."
fi

counters="f b"

declare -A bucket_counts
declare -A local_count
tmpfile=$(mktemp)

echo -n "Searching..." >&2
awk '/reported failed/ { printf("f,%s\nb,%s\n",$9,$14)}' $1 | sort -n | uniq -c > $tmpfile
echo -n ", mapping to buckets" >&2

buckets=()
currbuckets=()
inhost=0
depth_count=0

echo "buckets...,reported,reporter"

while read line; do  
	thirdcol=$(echo $line | awk '{print $3}')  
	forthcol=$(echo $line | awk '{print $4}')  
	if [ $(echo $thirdcol | grep -ic "^type$") -gt 0 ]; then  
		continue
	fi
	if [ $(echo $thirdcol | grep -c ^osd\.) -gt 0 ]; then    
		

		for j in $counters; do	
			local_count[$j]=$(awk -v p="${j},${thirdcol}" '{if ( $2 == p ) { print $1 }}' $tmpfile)
			if [ -z ${local_count[$j]} ]; then  
				local_count[$j]=0
			fi
		done

		for ((i = 0; i < ${#buckets[*]} ; i++)) {  
			bucket=${buckets[$i]}
			for j in $counters; do
				((bucket_counts[$j,$i]+=${local_count[$j]}))  
			done
			echo -n "${!bucket},"  
		}
		echo -n "$thirdcol"  
		for j in $counters; do  
			((bucket_counts[$j,$i]+=${local_count[$j]}))  
			echo -n ,${local_count[$j]}   
		done
		echo    
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
			for j in $counters; do   
				bucket_counts[$j,$i]=0
			done
		else                             
			highest_bucket=${#buckets[*]}
			for ((k = $highest_bucket; k > $havebucket; k--)) {  
				for ((i = 0; i < $k ; i++)); do              
					bucket=${buckets[$i]}                
					echo -n "${!bucket},"                
				done
				for j in $counters; do
					echo -n ${bucket_counts[$j,$k]},     
					bucket_counts[$j,$k]=0               
				done
				echo    
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
echo  >&2
