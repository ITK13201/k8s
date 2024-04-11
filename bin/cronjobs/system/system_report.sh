#!/bin/bash

set -u -o pipefail

CODE_BLOCK_SEPARATOR="\`\`\`"

# ===

### Create tmpfile ###
tmpfile=$(mktemp)
function rm_tmpfile {
  [[ -f "$tmpfile" ]] && rm -f "$tmpfile"
}
trap rm_tmpfile EXIT
trap 'trap - EXIT; rm_tmpfile; exit -1' INT PIPE TERM

# ===

### Space of File System ###
df -h | grep -e /dev/mapper/cs-root -e /dev/sd 2>&1 | tee "${tmpfile}"
message=$(cat "${tmpfile}")
status=$?
if [[ ${status} = 0 ]]; then
    level="info"
else
    level="error"
fi
discord-bot-cli -c "system" -t "Space of File System" -d "${CODE_BLOCK_SEPARATOR}${message}${CODE_BLOCK_SEPARATOR}" -l ${level}

exit 0
