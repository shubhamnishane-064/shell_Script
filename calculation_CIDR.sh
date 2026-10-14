#!/usr/bin/env bash
# cidr.sh - simple subnet calculator
# Usage: ./cidr.sh 192.168.1.130/26

set -euo pipefail

if [ $# -ne 1 ] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
  echo "Usage: $0 <ip>/<prefix>    example: $0 192.168.1.130/26"
  exit 2
fi

IP="${1%/*}"
PREFIX="${1#*/}"
[ "$PREFIX" -ge 0 ] && [ "$PREFIX" -le 32 ] || { echo "Prefix must be 0-32"; exit 2; }

to_int() { local IFS=.; read -r a b c d <<< "$1"
  for o in $a $b $c $d; do [ "$o" -le 255 ] || { echo "Bad IP octet: $o" >&2; exit 2; }; done
  echo $(( (a << 24) + (b << 16) + (c << 8) + d )); }
to_ip()  { echo "$(( ($1 >> 24) & 255 )).$(( ($1 >> 16) & 255 )).$(( ($1 >> 8) & 255 )).$(( $1 & 255 ))"; }

IPINT=$(to_int "$IP")
if [ "$PREFIX" -eq 0 ]; then MASK=0; else MASK=$(( (0xFFFFFFFF << (32 - PREFIX)) & 0xFFFFFFFF )); fi
NET=$(( IPINT & MASK ))
BCAST=$(( NET | (~MASK & 0xFFFFFFFF) ))
TOTAL=$(( 1 << (32 - PREFIX) ))

if   [ "$PREFIX" -ge 31 ]; then HOSTS=$TOTAL; FIRST=$NET; LAST=$BCAST
else HOSTS=$(( TOTAL - 2 )); FIRST=$(( NET + 1 )); LAST=$(( BCAST - 1 )); fi

printf "%-18s %s\n" "Address:"      "$IP/$PREFIX"
printf "%-18s %s\n" "Subnet mask:"  "$(to_ip $MASK)"
printf "%-18s %s\n" "Network:"      "$(to_ip $NET)"
printf "%-18s %s\n" "Broadcast:"    "$(to_ip $BCAST)"
printf "%-18s %s\n" "First host:"   "$(to_ip $FIRST)"
printf "%-18s %s\n" "Last host:"    "$(to_ip $LAST)"
printf "%-18s %s\n" "Usable hosts:" "$HOSTS"
