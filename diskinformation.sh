#!/usr/bin/env bash
# sysinfo.sh - print basic system information
set -euo pipefail

print_line() { echo "------------------------------------------"; }
print_line() { echo "-----hellow $(whoami) this is your system helth  "; }
echo "SYSTEM INFO for $(hostname)"
print_line
echo "User     : $(whoami)"
echo "Date     : $(date)"
echo "Uptime   : $(uptime -p)"
echo "Kernel   : $(uname -r)"
print_line
echo "Disk (root /):"
df -h / | tail -n 1
print_line
echo "Memory:"
free -m | awk 'NR==2 {printf "Used %s MB of %s MB\n", $3, $2}'
print_line
echo "Top 5 processes by CPU:"
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
