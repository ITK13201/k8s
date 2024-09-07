#!/bin/bash

set -eu

echo "[$(date -Iseconds)] Started restarting reployment."

container=$(kubectl -n minecraft get pods -o=jsonpath='{.items[?(@.metadata.labels.app=="minecraft-minecraft")].metadata.name}')

function exec_rcon_cmd() {
    kubectl exec -n minecraft -i pod/"$container" -- rcon-cli "$1"
}

exec_rcon_cmd "/say The server will restart in 10 minutes. Please move to a safe location."
sleep 5m
exec_rcon_cmd "/say The server will restart in 5 minutes. Please be prepared."
sleep 5m
exec_rcon_cmd "/stop"

sleep 5

kubectl -n minecraft rollout restart deployment/minecraft-minecraft

echo "[$(date -Iseconds)] Finished restarting reployment."
