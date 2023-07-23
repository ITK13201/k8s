#!/bin/bash

# master node
firewall-cmd --zone public --add-port 6443/tcp --permanent
firewall-cmd --zone public --add-port 2379-2380/tcp --permanent
firewall-cmd --zone public --add-port 10250/tcp --permanent
firewall-cmd --zone public --add-port 10251/tcp --permanent
firewall-cmd --zone public --add-port 10252/tcp --permanent

# worker node
firewall-cmd --zone public --add-port 10250/tcp --permanent
firewall-cmd --zone public --add-port 30000-32767/tcp --permanent

firewall-cmd --reload
