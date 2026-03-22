#!/bin/bash

# Check if a filename was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

awk '/========= BEGIN DEEP FLATTEN/{flag=1;next}/========= END DEEP FLATTEN/{flag=0}flag' "$1"
