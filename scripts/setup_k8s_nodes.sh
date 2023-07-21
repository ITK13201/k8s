#!/bin/bash

# Scheduling pods on control plane nodes
kubectl taint nodes --all node-role.kubernetes.io/master-
