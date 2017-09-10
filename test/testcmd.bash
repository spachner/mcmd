#!/usr/bin/env bash

exitCode=$1

     echo "Hello #1 from mcmd to stdout"
     echo "Sleep 1"
sleep 1

(>&2 echo "Hello #2 from mcmd to stderr")
     echo "Sleep 1"
sleep 1

     echo "Hello #3 from mcmd to stdout"
     echo "Sleep 1"
sleep 1

     echo "Hello #4 from mcmd to stdout"
     echo "Sleep 1"
sleep 1

(>&2 echo "Hello #5 from mcmd to stderr")

exit $exitCode