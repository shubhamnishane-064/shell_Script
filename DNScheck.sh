#!/usr/bin/env bash
# ^ shebang: run this file with bash (keep this line free of extra text)
# dns_simple.sh - very simple DNS check, every line explained
# Usage: ./dns_simple.sh google.com       (or run it with no argument to test google.com)

DOMAIN="${1:-google.com}"                 # domain to test: first argument, or google.com if none given
PUBLIC_DNS="8.8.8.8"                      # a public DNS server (Google) used as a comparison

echo "=== DNS check for: $DOMAIN ==="      # print a title

# ---------- Step 1: which DNS servers does this machine use? ----------
echo                                      # print an empty line
echo "1) DNS servers in /etc/resolv.conf:"   # print the step title
grep '^nameserver' /etc/resolv.conf || echo "   none found"   # show nameserver lines, or say none (a missing nameserver is a common problem)

# ---------- Step 2: lookup using the system's own DNS ----------
echo                                      # print an empty line
echo "2) Lookup with system DNS:"          # print the step title
SYSTEM_IP=$(getent hosts "$DOMAIN" | awk '{print $1}' | head -n 1)   # ask the OS (uses /etc/hosts and DNS), keep the first IP
if [ -n "$SYSTEM_IP" ]; then              # if we got an answer (variable is not empty)
  echo "   OK    $DOMAIN -> $SYSTEM_IP"   # show the IP found
else                                      # otherwise
  echo "   FAIL  no answer from system DNS"   # the system could not resolve the name
fi                                        # end of the if

# ---------- Step 3: lookup using a public DNS server ----------
echo                                      # print an empty line
echo "3) Lookup with public DNS ($PUBLIC_DNS):"   # print the step title
PUBLIC_IP=""                              # start with an empty value
if command -v dig >/dev/null 2>&1; then   # if the dig tool is installed
  PUBLIC_IP=$(dig +short +time=3 +tries=1 @"$PUBLIC_DNS" "$DOMAIN" A | grep -E '^[0-9.]+$' | head -n 1)   # ask 8.8.8.8 for the A record, keep only IP-looking lines, take the first
  if [ -n "$PUBLIC_IP" ]; then            # if we got an IP
    echo "   OK    $DOMAIN -> $PUBLIC_IP"  # show the IP found
  else                                    # otherwise
    echo "   FAIL  no answer from $PUBLIC_DNS"   # the public server gave no IP
  fi                                      # end of the inner if
else                                      # dig is not installed
  echo "   SKIP  dig not installed (sudo apt install dnsutils)"   # tell the user how to install it
fi                                        # end of the if

# ---------- Step 4: result ----------
echo                                      # print an empty line
echo "4) Result:"                          # print the step title
if [ -n "$SYSTEM_IP" ]; then              # system DNS worked
  echo "   DNS is working."                # good news
  exit 0                                  # exit code 0 = success
elif [ -n "$PUBLIC_IP" ]; then            # system failed but the public server worked
  echo "   Problem is in MY DNS settings. Check /etc/resolv.conf or run: resolvectl status"   # hint where to look
  exit 1                                  # exit code 1 = problem found
else                                      # both failed
  echo "   Both failed: the name may not exist, or there is no network. Try: ping -c 2 8.8.8.8"   # hint the next test
  exit 1                                  # exit code 1 = problem found
fi                                        # end of the if