# ceph-log-parsers
Tools for parsing ceph logs to help with troubleshooting various issues.

## Tool Explanations:
NOTE: I've shortened the sample outputs below with elipses for the sake of brevity.


- map_events_to_buckets.sh
Provide a 'ceph.log' and the text file output of 'ceph osd tree' and this script will output a count of slow requests (local, subop and total),'failed', 'boot' and 'wrongly marked me down' entries mapped to the leaf / buckets to which they were reported against.

###### Example:
```
# ceph osd tree > ceph_osd_tree.txt
# ./map_events_to_buckets.sh ceph.log ceph_osd_tree.txt > events.csv
Searching for... slow, subops, failed, boot, wrongly marked down

# cat events.csv
buckets...,slow primary,slow subop, total slow,failed,boot,wrongly down
default,rack1,ceph-storage-003,osd.0,775,398,1173,174,174,176
default,rack1,ceph-storage-003,osd.6,725,171,896,175,176,176
default,rack1,ceph-storage-003,osd.10,618,352,970,177,177,179
default,rack1,ceph-storage-003,osd.15,578,829,1407,175,175,176
...
default,rack1,ceph-storage-003,6831,3842,10673,1741,1742,1750,
default,rack1,ceph-storage-004,osd.423,783,397,1180,174,174,175
default,rack1,ceph-storage-004,osd.425,882,517,1399,171,171,171
default,rack1,ceph-storage-004,osd.427,784,795,1579,177,177,177
default,rack1,ceph-storage-004,osd.429,715,327,1042,169,169,167
...
default,rack1,ceph-storage-004,7238,6809,14047,1725,1726,1727,
...
default,rack1,86695,83655,170350,13597,13621,13669,
default,rack2,ceph-storage-020,osd.149,720,573,1293,172,172,172
default,rack2,ceph-storage-020,osd.153,913,140,1053,170,170,175
default,rack2,ceph-storage-020,osd.158,1107,487,1594,170,171,173
default,rack2,ceph-storage-020,osd.163,989,248,1237,170,170,170
...
default,rack2,ceph-storage-020,7801,3220,11021,1711,1714,1720,
default,rack2,ceph-storage-021,osd.150,552,178,730,0,0,0
default,rack2,ceph-storage-021,osd.154,820,738,1558,0,0,0
default,rack2,ceph-storage-021,osd.159,0,0,0,0,0,0
....
default,rack2,ceph-storage-021,5093,3466,8559,0,0,0,
...
default,rack2,97265,87545,184810,11958,11968,12038,
...
default,rack3,154202,58709,212911,2357,2357,2365,
default,338162,229909,568071,27912,27946,28072,
```

- map_reporters_to_buckets.sh
Provide with a ceph-mon.log and text output file from 'ceph osd tree' and this script will generate a mapping of 'reported failed' (reported and reporters) counts as a result.

```
# ceph osd tree > ceph_osd_tree.txt
# ./map_reporters_to_buckets.sh ceph-mon.log ceph_osd_tree.txt > reporters.csv
Searching..., mapping to buckets

# cat reporters.csv
buckets...,reported,reporter
default,rack1,ceph-storage-003,osd.0,2411,1520
default,rack1,ceph-storage-003,osd.6,1880,2198
default,rack1,ceph-storage-003,osd.10,2456,1663
default,rack1,ceph-storage-003,osd.15,1978,2677
...
default,rack1,ceph-storage-003,24256,22256,
default,rack1,ceph-storage-004,osd.423,3869,1893
default,rack1,ceph-storage-004,osd.425,3024,2832
default,rack1,ceph-storage-004,osd.427,2219,2439
...
default,rack1,ceph-storage-004,27784,21096,
...
default,rack1,206045,167742,
...
default,rack2,199356,137798,
...
default,rack3,ceph-storage-046,osd.254,34761,46650
default,rack3,ceph-storage-046,osd.259,32485,38331
default,rack3,ceph-storage-046,osd.264,33657,48924
default,rack3,ceph-storage-046,osd.269,31560,48421
default,rack3,ceph-storage-046,309241,409805,
...
default,rack3,313686,413547,
default,719087,719087,

```

- map_slow_requests_to_buckets.sh
Provide the 'ceph.log' and a text file output of 'ceph osd tree' and this script will output a raw count of slow requests (combined primary and subops in one counter) mapped to the leaf / buckets to which they were reported against.  This script was created prior to the 'events' script, and is therefore left available but is supersceded by the 'events' script.

###### Example:
```
# ceph osd tree > ceph_osd_tree.txt
# ./map_slow_requests_to_buckets.sh ceph.log ceph_osd_tree.txt > slow.csv
# cat slow.csv

default,rack1,ceph-storage-003,osd.0,1173
default,rack1,ceph-storage-003,osd.6,896
default,rack1,ceph-storage-003,osd.10,970
default,rack1,ceph-storage-003,osd.15,1407
default,rack1,ceph-storage-003,osd.20,1441
default,rack1,ceph-storage-003,osd.25,821
...
default,rack1,ceph-storage-003,10673
default,rack1,ceph-storage-004,osd.423,1180
default,rack1,ceph-storage-004,osd.425,1399
default,rack1,ceph-storage-004,osd.427,1579
default,rack1,ceph-storage-004,osd.429,1042
...
default,rack1,ceph-storage-004,14047
....
default,rack1,170350
default,rack2,ceph-storage-017,0
default,rack2,ceph-storage-020,osd.149,1293
default,rack2,ceph-storage-020,osd.153,1053
default,rack2,ceph-storage-020,osd.158,1594
default,rack2,ceph-storage-020,osd.163,1237
...
default,rack2,ceph-storage-020,11021
default,rack2,ceph-storage-021,osd.150,730
default,rack2,ceph-storage-021,osd.154,1558
default,rack2,ceph-storage-021,osd.159,0
default,rack2,ceph-storage-021,osd.164,399
default,rack2,ceph-storage-021,osd.169,1016
...
default,rack2,ceph-storage-021,8559
...
default,rack2,184810
...
default,rack3,212911
default,568071
```



