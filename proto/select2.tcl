#!/usr/bin/tclsh
# Copyright 2019-2020 Dolthub, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Run this script to generate a larger prototype test script for
# sqllogictest.
#
expr {srand(0)}

# Scramble the $inlist into a random order.
#
proc scramble {inlist} {
  set y {}
  foreach x $inlist {
    lappend y [list [expr {rand()}] $x]
  }
  set y [lsort $y]
  set outlist {}
  foreach x $y {
    lappend outlist [lindex $x 1]
  }
  return $outlist
}

puts {hash-threshold 8}
puts {}
puts {statement ok}
puts {CREATE TABLE t1(a INTEGER, b INTEGER, c INTEGER, d INTEGER, e INTEGER)}
puts {}

for {set i 0} {$i<30} {incr i} {
  set base [expr {$i*5+100}]
  set values {}
  for {set j 0} {$j<5} {incr j} {
    if {rand()<0.1} {
      lappend values NULL
    } else {
      lappend values [expr {$j+$base}]
    }
  }
  set values [scramble $values]
  set cols [scramble {a b c d e}]
  set sql "INSERT INTO t1([join $cols ,]) VALUES([join $values ,])"
  puts "statement ok"
  puts $sql
  puts ""
}

set rexpr {
  a b c d e
  a-b b-c c-d d-e
  a+b*2 a+b*2+c*3 a+b*2+c*3+d*4 a+b*2+c*3+d*4+e*5
  (a+b+c+d+e)/5
  abs(a) abs(b-c)
  {(SELECT count(*) FROM t1 AS x WHERE x.b<t1.b)}
  {(SELECT count(*) FROM t1 AS x WHERE x.c>t1.c AND x.d<t1.d)}
  {CASE WHEN c>(SELECT avg(c) FROM t1) THEN a*2 ELSE b*10 END}
  {CASE WHEN a<b-3 THEN 111 WHEN a<=b THEN 222
        WHEN a<b+3 THEN 333 ELSE 444 END}
  {CASE a+1 WHEN b THEN 111 WHEN c THEN 222
        WHEN d THEN 333  WHEN e THEN 444 ELSE 555 END}
}
set nrexpr [llength $rexpr]
set sequence {}
set type {}
for {set i 1} {$i<=$nrexpr} {incr i} {
  lappend sequence $i
  append type I
}
set wexpr {
  a>b
  b>c
  c>d
  d>e
  {a IS NULL}
  {b IS NOT NULL}
  coalesce(a,b,c,d,e)<>0
  {c BETWEEN b-2 AND d+2}
  {d NOT BETWEEN 110 AND 150}
  {e+d BETWEEN a+b-10 AND c+130}
  {(a>b-2 AND a<b+2)}
  {(e>a AND e<b)}
  {(c<=d-2 OR c>=d+2)}
  {(e>c OR e<d)}
  {EXISTS(SELECT 1 FROM t1 AS x WHERE x.b<t1.b)}
}
set nwexpr [llength $wexpr]

for {set i 0} {$i<1000} {incr i} {
  set n [expr {int(rand()*7)+1}]
  set r [lrange [scramble $rexpr] 1 $n]
  set sql "SELECT [join $r ",\n       "]\n  FROM t1"
  set m [expr {int(rand()*4)}]
  if {$m>0} {
    set op [expr {rand()>0.5 ? "\n    OR " : "\n   AND "}]
    set w [lrange [scramble $wexpr] 1 $m]
    append sql "\n WHERE [join $w $op]"
  }
  puts "query [string range $type 1 $n] rowsort"
  puts "$sql"
  puts ""
}
