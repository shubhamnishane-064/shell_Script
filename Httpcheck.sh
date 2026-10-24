#!/usr/bin/env bash
# ^ shebang: run this file with bash (keep this line free of extra text)
# httpcheck.sh - check a website: status code, timing, redirects and certificate expiry
# Usage: ./httpcheck.sh https://example.com
#        ./httpcheck.sh example.com                          (https:// is added for me)
#        INSECURE=1 ./httpcheck.sh https://localhost:8443    (skip certificate check, tests only)
# Exit code: 0 = OK (2xx/3xx), 1 = problem, 2 = wrong usage

set -uo pipefail                              # stop on unset variables and failed pipes (no -e, so I can handle errors myself)

# ---------- 1. CHECK THE INPUT ----------
URL="${1:-}"                                  # first argument is the URL (empty if none given)
if [ -z "$URL" ]; then                        # if no URL was given
  echo "Usage: $0 <url>      example: $0 https://example.com"   # show how to use the script
  exit 2                                      # exit code 2 = wrong usage
fi                                            # end of the input check
[[ "$URL" =~ ^https?:// ]] || URL="https://$URL"   # if the URL does not start with http:// or https://, add https://

# ---------- 2. PREPARE THE CURL COMMAND ----------
CURL_OPTS=(-s -o /dev/null -L --max-time 15 --connect-timeout 5)   # -s silent, -o /dev/null drop the page, -L follow redirects, stop after 15 s (5 s to connect)
[ "${INSECURE:-0}" = "1" ] && CURL_OPTS+=(-k) # if INSECURE=1 was set, also skip the certificate check (-k)

FORMAT='%{http_code} %{time_namelookup} %{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total} %{num_redirects} %{remote_ip} %{url_effective}'   # values for curl to print: status, DNS, connect, TLS, first byte, total, redirects, IP, final URL
OUT=$(curl "${CURL_OPTS[@]}" -w "$FORMAT" "$URL")   # run curl once and keep the printed values in OUT
RC=$?                                         # RC = curl's exit code (0 means curl itself worked)

echo "HTTP check for: $URL"                   # print a title
echo "------------------------------------------"   # print a line

# ---------- 3. IF CURL FAILED, EXPLAIN WHY ----------
if [ "$RC" -ne 0 ]; then                      # if curl did not finish successfully
  case "$RC" in                               # pick a reason from the exit code
    6)  WHY="could not resolve the host (DNS problem)" ;;                      # code 6 = DNS failed
    7)  WHY="connection refused or failed (service down, wrong port, firewall)" ;;   # code 7 = cannot connect
    28) WHY="timed out (slow server or blocked by a firewall)" ;;              # code 28 = timeout
    35) WHY="TLS handshake failed" ;;                                          # code 35 = TLS error
    52) WHY="server sent an empty reply" ;;                                    # code 52 = empty reply
    56) WHY="connection reset while receiving data" ;;                         # code 56 = connection reset
    60) WHY="certificate problem (expired, wrong name or untrusted)" ;;        # code 60 = certificate error
    *)  WHY="curl error" ;;                                                    # any other code
  esac                                        # end of the case
  echo "RESULT: FAIL  curl exit code $RC - $WHY"   # show the failure and the reason
  exit 1                                      # exit code 1 = problem found
fi                                            # end of the failure check

# ---------- 4. SHOW THE NUMBERS ----------
read -r CODE T_DNS T_CONN T_TLS T_TTFB T_TOTAL REDIR IP FINAL <<< "$OUT"   # split the curl output into 9 variables
ms() { awk -v t="$1" 'BEGIN{printf "%.0f", t*1000}'; }   # helper function: turn seconds into milliseconds

echo "Status code : $CODE"                    # HTTP status code (200, 404, 500 ...)
echo "Server IP   : $IP"                      # IP address that answered
echo "Redirects   : $REDIR  (final URL: $FINAL)"   # how many redirects were followed and where we ended up
echo "DNS lookup  : $(ms "$T_DNS") ms"        # time to resolve the name
echo "TCP connect : $(ms "$T_CONN") ms"       # time to open the connection
if [[ "$FINAL" =~ ^https:// ]]; then          # only for HTTPS sites
  echo "TLS done at : $(ms "$T_TLS") ms"      # time until the TLS handshake finished
fi                                            # end of the HTTPS check
echo "First byte  : $(ms "$T_TTFB") ms"       # time until the server started to answer (slow app shows here)
echo "Total       : $(ms "$T_TOTAL") ms"      # whole request time

# ---------- 5. CERTIFICATE EXPIRY (HTTPS ONLY) ----------
if [[ "$FINAL" =~ ^https://([^/:]+)(:([0-9]+))? ]] && command -v openssl >/dev/null 2>&1; then   # if the final URL is https and openssl exists, also capture host and port
  HOST="${BASH_REMATCH[1]}"; PORT="${BASH_REMATCH[3]:-443}"   # host name, and port (443 if none given)
  END=$(echo | openssl s_client -servername "$HOST" -connect "$HOST:$PORT" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)   # connect, read the certificate, keep only the end date
  if [ -n "$END" ]; then                      # if a date was found
    DAYS=$(( ( $(date -d "$END" +%s) - $(date +%s) ) / 86400 ))   # (end date - now) in seconds, divided by 86400 seconds per day
    NOTE=""; [ "$DAYS" -lt 15 ] && NOTE="  <-- renew soon!"       # warn when fewer than 15 days are left
    echo "Certificate : expires in $DAYS days ($END)$NOTE"          # show the days left
  fi                                          # end of the date check
fi                                            # end of the certificate check

# ---------- 6. FINAL RESULT AND EXIT CODE ----------
echo "------------------------------------------"   # print a line
case "$CODE" in                               # decide by the first digit of the status code
  2*) echo "RESULT: OK    success ($CODE)";            exit 0 ;;   # 2xx = success, exit 0
  3*) echo "RESULT: OK    redirect ($CODE)";           exit 0 ;;   # 3xx = redirect, exit 0
  4*) echo "RESULT: FAIL  client error ($CODE) - check the URL, login or permissions"; exit 1 ;;   # 4xx = my request is wrong, exit 1
  5*) echo "RESULT: FAIL  server error ($CODE) - check the app and web server logs";   exit 1 ;;   # 5xx = server problem, exit 1
  *)  echo "RESULT: FAIL  unexpected code ($CODE)";    exit 1 ;;   # anything else, exit 1
esac                                          # end of the case