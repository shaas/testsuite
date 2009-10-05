#!/usr/bin/expect

if {$argc != 1} {
   puts "usage: $argv0 <filename>"
   exit 1
}

set filename [lindex $argv 0]

if {![file exists $filename]} {
   puts "file $filename doesn't exist"
   exit 2
}

set timestamp [file mtime $filename]
puts $timestamp
exit 0
