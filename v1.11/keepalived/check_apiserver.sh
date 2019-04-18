#!/bin/bash

# if check error then repeat check for 12 times, else exit
err=0
for k in $(seq 1 12)
do
    check_code=$(curl -k https://localhost:6443)
    if [[ $check_code == "" ]]; then
        err=$(expr $err + 1)
        sleep 5
        continue
    else
        err=0
        break
    fi
done

if [[ $err != "0" ]]; then
    # if apiserver is down send SIG=1
    echo 'apiserver error!'
    exit 1
else
    # if apiserver is up send SIG=0
    echo 'apiserver normal!'
    exit 0
fi
