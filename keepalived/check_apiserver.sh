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
    # if apiserver down stop keepalived
    echo "systemctl stop keepalived"
    /usr/bin/systemctl stop keepalived
    exit 1
else
    # if apiserver up check keepalived and start it up
    check_keeaplived=$(ps -ef| grep keepalived | grep -v 'color=auto' | wc -l)
    if [[ $check_keeaplived == "0" ]]; then
        /usr/bin/systemctl start keepalived
    fi
    exit 0
fi
