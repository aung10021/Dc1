#!/bin/bash

status=$(sudo service --status-all |grep squid)
if [[ $status == *"[ - ]"* ]]; then
  sudo service squid start
fi
