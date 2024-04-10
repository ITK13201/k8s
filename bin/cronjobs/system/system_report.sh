#!/bin/bash

set -u -o pipefail

CODE_BLOCK_SEPARATOR="\`\`\`"

# ===

### Space of File System ###
message=$(df -h | grep -e /dev/mapper/cs-root -e /dev/sd 2>&1 | tee /dev/tty)
status=$?
if [[ ${status} = 0 ]]; then
    level="info"
else
    level="error"
fi
discord-bot-cli -c "system" -t "Space of File System" -d "${CODE_BLOCK_SEPARATOR}${message}${CODE_BLOCK_SEPARATOR}" -l ${level}

exit 0
