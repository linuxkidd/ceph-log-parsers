# ceph-log-parsers
Tools for parsing ceph logs to help with troubleshooting various issues.

## Tool Explanations:
NOTE: I've shortened the sample outputs below with elipses for the sake of brevity.
- rgw_req_timing.sh
Provide the `ceph.log` and this script will provide an output showing the time between the start and stop of every deep-scrub.  The output format is csv, with the first column being the deep-scrub time in seconds, second column being the 'deep-scrub' line which stopped the timer.  The start/stop lines are keyed on the pg.id.  At the end of the processing, a Min,Avg,Max output is also provided, along with the 'deep-scrub' completed line for the Min and Max processing times.

###### Example:
```
# ./deep-scrub_timing.sh /var/log/ceph/ceph.log > ~/deep-scrub_timings.csv
# cat ~/deep-scrub_timings.csv

0.0155821,2018-01-16 03:44:06.068707 osd.764 10.129.152.42:6851/3796002 4467 : cluster [INF] 29.243 deep-scrub ok
0.0110428,2018-01-16 03:44:11.223353 osd.447 10.129.152.33:6851/3784262 4900 : cluster [INF] 29.5ad deep-scrub ok
0.0009799,2018-01-16 03:45:59.345522 osd.927 10.129.152.50:6836/2106288 6823 : cluster [INF] 20.e9 deep-scrub ok
0.002249,2018-01-16 03:46:04.488109 osd.284 10.129.152.30:6848/3526172 4303 : cluster [INF] 18.2f deep-scrub ok
0.000980854,2018-01-16 03:47:26.628785 osd.540 10.129.152.40:6824/4041304 5864 : cluster [INF] 23.238 deep-scrub ok
0.00139022,2018-01-16 03:47:27.402259 osd.684 10.129.152.42:6818/3777592 5148 : cluster [INF] 17.26d deep-scrub ok
...
Min,Avg,Max
0.000564098,248.451,846.795
Min Req: 2018-01-16 11:28:00.908817 osd.4 10.129.152.25:6837/3496196 5784 : cluster [INF] 48.32 deep-scrub ok
Max Req: 2018-01-17 01:13:12.793967 osd.131 10.129.152.23:6814/3605203 3452 : cluster [INF] 30.7f7 deep-scrub ok
```

- iops_histo.sh
Provide a 'ceph.log', this script will output a CSV file that can be graphed to understand the IOPs histogram for the time covered by the ceph.log.  Left column is thousand IOPs, right column is how many 'pgmap' entries fall into that thousand.

###### Example:
```
# ./iops_histo.sh ceph.log > iops_histo.csv
# cat iops_histo.csv

0,628
1,124
2,1986
3,8339
4,4218
5,3705
6,3233
7,2574
8,2013
9,1453
10,890
11,607
12,413
13,349
14,287
15,238
16,252
17,214
18,173
```

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

- rgw_req_timing.sh
Provide the `radosgw.log` and this script will provide an output showing the time between the start and return of every RGW request.  The output format is csv, with the first column being the request time in seconds, second column being the 'req done' line which stopped the timer.  The start/stop lines are keyed on the request ID assigned by RGW.  At the end of the processing, a Min,Avg,Max output is also provided, along with the 'req done' line for the Min and Max request times.

###### Example:
```
# ./rgw_req_timing.sh /var/log/ceph/ceph-rgw-myhostname.log > ~/req_timings.csv
# cat ~/req_timings.csv

0.187219,2018-01-16 03:47:01.622215 2af878cd7700  1 ====== req done req=0x2af878cd1710 op status=0 http_status=200 ======
0.051897,2018-01-16 03:47:01.989993 2af8a132d700  1 ====== req done req=0x2af8a1327710 op status=0 http_status=200 ======
0.181928,2018-01-16 03:47:02.045216 2af878cd7700  1 ====== req done req=0x2af878cd1710 op status=0 http_status=200 ======
0.052496,2018-01-16 03:47:02.047359 2af8a5335700  1 ====== req done req=0x2af8a532f710 op status=0 http_status=200 ======
0.279186,2018-01-16 03:47:02.207797 2af87e7e5700  1 ====== req done req=0x2af87e7df710 op status=0 http_status=200 ======
0.16574,2018-01-16 03:47:02.447974 2af878cd7700  1 ====== req done req=0x2af878cd1710 op status=0 http_status=200 ======
0.29716,2018-01-16 03:47:02.712994 2af87e7e5700  1 ====== req done req=0x2af87e7df710 op status=0 http_status=200 ======
0.186362,2018-01-16 03:47:02.828799 2af878cd7700  1 ====== req done req=0x2af878cd1710 op status=0 http_status=200 ======
0.236106,2018-01-16 03:47:02.931637 2af88ab00700  1 ====== req done req=0x2af88aafa710 op status=0 http_status=200 ======
0.0516322,2018-01-16 03:47:02.952181 2af87f0e7700  1 ====== req done req=0x2af87f0e1710 op status=0 http_status=200 ======
...
Min,Avg,Max
0.000127792,0.73737,1200.11
Min Req: 2018-01-16 15:46:07.383273 2af89230f700  1 ====== req done req=0x2af892309710 op status=0 http_status=400 ======
Max Req: 2018-01-16 12:09:07.163211 2af89130d700  1 ====== req done req=0x2af891307710 op status=0 http_status=200 ======
```
