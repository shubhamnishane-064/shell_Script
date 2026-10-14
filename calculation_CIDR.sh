#!/usr/bin/env bash
# cidr.sh - simple subnet calculator     # what the script does
# Usage: ./cidr.sh 192.168.1.130/26      # how to run it

set -euo pipefail                        # stop on error, unset variable, or failed pipe

# ---------- 1. CHECK THE INPUT ----------
if [ $# -ne 1 ] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then   # need exactly 1 argument shaped like a.b.c.d/n ($# = number of arguments)
  echo "Usage: $0 <ip>/<prefix>    example: $0 192.168.1.130/26"                    # show how to use it ($0 = script name)
  exit 2                                 # exit code 2 = wrong usage
fi                                       # end of the input check

IP="${1%/*}"                             # take the text BEFORE the "/"  -> 192.168.1.130
PREFIX="${1#*/}"                         # take the text AFTER the "/"   -> 26
[ "$PREFIX" -ge 0 ] && [ "$PREFIX" -le 32 ] || { echo "Prefix must be 0-32"; exit 2; }   # a valid prefix is between 0 and 32

# ---------- 2. HELPER FUNCTIONS ----------
to_int() {                               # function: turn an IP like 192.168.1.130 into one big number
  local IFS=.                            # split text on dots (local = only inside this function)
  read -r a b c d <<< "$1"               # put the 4 octets into a, b, c, d
  for o in $a $b $c $d; do               # loop over each octet
    [ "$o" -le 255 ] || { echo "Bad IP octet: $o" >&2; exit 2; }   # an octet above 255 is not valid
  done                                   # end of the loop
  echo $(( (a << 24) + (b << 16) + (c << 8) + d ))   # a*2^24 + b*2^16 + c*2^8 + d  (shift left = multiply by powers of 2)
}                                        # end of to_int

to_ip() {                                # function: turn the big number back into a.b.c.d
  echo "$(( ($1 >> 24) & 255 )).$(( ($1 >> 16) & 255 )).$(( ($1 >> 8) & 255 )).$(( $1 & 255 ))"   # shift right, then keep only the last 8 bits (& 255) for each octet
}                                        # end of to_ip

# ---------- 3. CALCULATE ----------
IPINT=$(to_int "$IP")                    # IP as a number
if [ "$PREFIX" -eq 0 ]; then             # special case: /0 means no network bits
  MASK=0                                 # mask is all zeros
else                                     # normal case
  MASK=$(( (0xFFFFFFFF << (32 - PREFIX)) & 0xFFFFFFFF ))   # start with 32 ones, shift left to leave PREFIX ones, then keep 32 bits
fi                                       # end of the mask calculation
NET=$(( IPINT & MASK ))                  # network address = IP AND mask (host bits become 0)
BCAST=$(( NET | (~MASK & 0xFFFFFFFF) ))  # broadcast = network OR the host bits set to 1 (~MASK flips the mask)
TOTAL=$(( 1 << (32 - PREFIX) ))          # total addresses = 2^(32 - prefix)

if [ "$PREFIX" -ge 31 ]; then            # /31 and /32 are special small networks
  HOSTS=$TOTAL                           # all addresses are usable
  FIRST=$NET                             # first host = network address
  LAST=$BCAST                            # last host = broadcast address
else                                     # normal networks (/30 and bigger)
  HOSTS=$(( TOTAL - 2 ))                 # usable hosts = total minus network and broadcast
  FIRST=$(( NET + 1 ))                   # first host = network address + 1
  LAST=$(( BCAST - 1 ))                  # last host = broadcast address - 1
fi                                       # end of the host calculation

# ---------- 4. SHOW THE RESULT ----------
printf "%-18s %s\n" "Address:"      "$IP/$PREFIX"        # the input as given (%-18s = left-aligned, 18 wide)
printf "%-18s %s\n" "Subnet mask:"  "$(to_ip $MASK)"      # mask as a.b.c.d, e.g. 255.255.255.192
printf "%-18s %s\n" "Network:"      "$(to_ip $NET)"       # network address
printf "%-18s %s\n" "Broadcast:"    "$(to_ip $BCAST)"     # broadcast address
printf "%-18s %s\n" "First host:"   "$(to_ip $FIRST)"     # first usable IP
printf "%-18s %s\n" "Last host:"    "$(to_ip $LAST)"      # last usable IP
printf "%-18s %s\n" "Usable hosts:" "$HOSTS"               # how many hosts fit in this subnet