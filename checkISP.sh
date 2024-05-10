#!/bin/bash

max_timeout=5
connect_timeout=5
retries=3

source /home/pi/log.sh

fetch_isp() {
  local attempt=1
  while [ $attempt -le $retries ]; do
    isp=$(curl -sSk --ipv4 --max-time $max_timeout --connect-timeout $connect_timeout ipinfo.io/org?token=abfaf07ed42402)
    if [ -n "$isp" ]; then  # Check if variable is non-empty
      echo "$isp"
      return 0
    else
      echo "Attempt $attempt of $retries failed, trying again..."
      ((attempt++))
    fi
  done
  echo "Failed to obtain ISP data after $retries attempts."
  return 1
}

isp=$(fetch_isp)

if [ $? -eq 0 ]; then  # Check if fetch_isp was successful
  echo $isp
  if echo "$isp" | grep -qi 'Rogers'; then
    ecrit "ISP failed over to Rogers" true
    exit 1
  elif echo "$isp" | grep -qi 'CIK'; then
    case "$HOSTNAME" in
      Monkeebutt)
        exit 0
        ;;
      Harbormaster)
        exit 1
        ;;
      *)
        exit 0
        ;;
    esac
  elif echo "$isp" | grep -qi 'tzulo'; then
    exit 0
  elif echo "$isp" | grep -qi 'Datacamp'; then
    exit 0
  else
    ecrit "ISP not recognized: '$isp'" false
    exit 1
  fi
else
  # Handle case where ISP data could not be fetched
  ecrit "Failed to fetch ISP data" false
  exit 1
fi
