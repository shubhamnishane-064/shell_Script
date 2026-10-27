#!/usr/bin/env bash
# ^ shebang: run this file with bash (keep this line free of extra text)
# portcheck.sh - tell if a TCP port is OPEN, CLOSED or FILTERED
# Usage: ./portcheck.sh <host> <port> [port ...]
#        ./portcheck.sh example.com 80 443 22
#        TIMEOUT=5 ./portcheck.sh 10.0.1.20 5432
# Meaning:
#   OPEN      the connection worked (something is listening)
#   CLOSED    "connection refused" fast: host is up, nothing listens (or a firewall REJECT rule)
#   FILTERED  no answer until the timeout: a firewall / Security Group is dropping packets
# Exit code: 0 = all ports open, 1 = at least one not open, 2 = wrong usage

set -uo pipefail                              # stop on unset variables and failed pipes (no -e: a closed port must not stop the script)

# ---------- 1. CHECK THE INPUT ----------
HOST="${1:-}"                                 # first argument is the host name or IP (empty if missing)
if [ -z "$HOST" ] || [ $# -lt 2 ]; then       # need a host AND at least one port ($# = number of arguments)
  echo "Usage: $0 <host> <port> [port ...]"  # show how to use the script ($0 = script name)
  exit 2                                      # exit code 2 = wrong usage
fi                                            # end of the input check
shift                                         # remove the host from the list, so "$@" holds only the ports
TIMEOUT="${TIMEOUT:-3}"                       # seconds to wait for an answer (default 3, can be set from outside)
BAD=0                                         # becomes 1 if any port is not open

# ---------- 2. TEST EACH PORT ----------
for PORT in "$@"; do                          # loop over every port given
  if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then   # a valid port is a number from 1 to 65535
    echo "$PORT: not a valid port"            # tell the user
    BAD=1                                     # count it as a problem
    continue                                  # skip to the next port
  fi                                          # end of the port check
  START=$(date +%s.%N)                        # time before the test, in seconds with decimals
  timeout "$TIMEOUT" bash -c 'exec 3<>/dev/tcp/$1/$2' _ "$HOST" "$PORT" 2>/dev/null   # try to open a TCP connection; host and port are passed as arguments, never pasted into the command text (safer)
  RC=$?                                       # RC = result: 0 connected, 124 timed out, anything else = refused or error
  MS=$(awk -v s="$START" -v e="$(date +%s.%N)" 'BEGIN{printf "%.0f", (e-s)*1000}')   # time taken, converted to milliseconds

# ---------- 3. SHOW THE RESULT ----------
  case "$RC" in                               # decide by the result code
    0)   printf "%-6s OPEN      (connected in %s ms)\n" "$PORT" "$MS" ;;   # connected: something is listening
    124) printf "%-6s FILTERED  (no answer for %ss: firewall or Security Group dropping packets?)\n" "$PORT" "$TIMEOUT"; BAD=1 ;;   # timeout: packets are being dropped
    *)   printf "%-6s CLOSED    (refused in %s ms: host is reachable; nothing listening, or a firewall REJECT rule)\n" "$PORT" "$MS"; BAD=1 ;;   # refused: reachable, but no listener (or REJECT)
  esac                                        # end of the case
done                                          # end of the loop
exit "$BAD"                                   # 0 if every port was open, otherwise 1
