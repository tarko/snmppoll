snmppoll
========

Almost realtime (5 sec interval) ifIn/OutOctets poller.


Examples
========

```
$ ./poll.pl hostname community
Interfaces found: 
511   ge-1/0/0        
512   ge-1/0/1        
513   ge-1/0/2        <ifAlias removed>
514   ge-1/0/3        <ifAlias removed>
515   ge-1/0/2.0      
516   ge-1/0/3.0      
517   ge-1/1/0        <ifAlias removed>
518   ge-1/1/1        
519   ge-1/1/0.0      

Enter ifindexes to monitor, separated by whitespace: 523 513
1347907338 ge-4/1/0-in    ge-4/1/0-out   ge-1/0/2-in    ge-1/0/2-out   
1347907343 955 069 310    1 388 067 529  147 269 173    135 724 521    
1347907348 1 459 875 037  2 092 862 834  97 604 888     99 948 156     
^C

Maximum values recorded:
ge-4/1/0-in    ge-4/1/0-out   ge-1/0/2-in    ge-1/0/2-out   
1 459 875 037  2 092 862 834  147 269 173    135 724 521    
```

Caveats
=======
Some platforms are only updating interface counters every 10 or more seconds. It is safe to increase sleep interval by modifying code but it should really be configurable.


License
=======
MIT License.  Copyright 2012 Tarko Tikan.
