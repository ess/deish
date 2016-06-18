#!/bin/bash -
#===============================================================================
#
#          FILE:  deish.sh
# 
#   DESCRIPTION:  On-cluster troubleshooting utilities for Deis v1 clusters
#       VERSION:  0.0.1
#===============================================================================

#-------------------------------------------------------------------------------
#  Internal Utilities
#-------------------------------------------------------------------------------

defined() {
  [ -n "${1}" ]
}

i_am_groot() {
  [ "$(whoami)" = 'root' ]
}

#-------------------------------------------------------------------------------
#  Docker Firewall Helpers
#-------------------------------------------------------------------------------

# Interface to iptables
#
# If logged in as root, this simply passes all of its arguments along to
# `iptables`. If logged in as a user, it does the same via `sudo iptables`.
#
# If no arguments are given, an error is recorded and the return status is 1
#
# Example:
#
#   ipt -t nat -S
ipt() {
  if ! defined "${@}"
  then
    echo "Nothing passed to ipt" >&2
    return 1
  fi

  if i_am_groot
  then
    iptables ${@}
  else
    sudo iptables ${@}
  fi
}

# List out the names of the currently running containers
container_names() {
  docker ps | awk '{print $NF}' | grep -v 'NAMES'
}

# Get the IP address associated with the given named container
#
# Example:
#
#   container_ips my-container
container_ips() {
  if ! defined "${1}"
  then
    echo "no container name passed to container_ips" >&2
    return 1
  fi

  docker inspect "${1}" | grep '"IPAddress"' | awk '{print $NF}' | sed -e 's/"//g' | sed -e 's/,//g'
}

# List out the IP address of each known named container
all_container_ips() {
  local container=""

  for container in $(container_names)
  do
    container_ip "${container}"
  done | sort | uniq
}

# Save the all_container_ips output for further processing
record_all_container_ips() {
  all_container_ips > all_container_ips.txt
}

# List out the IP addresses referenced by Docker NAT rules
nat_ips() {
  ipt -t nat -S DOCKER | awk '{print $NF}' | grep -v 'DOCKER' | cut -d : -f 1 | sort | uniq
}

# Save the nat_ips output for further processing
record_nat_ips() {
  nat_ips > nat_ips.txt
}

# Get a list of container IP addresses that may be bad
#
# Specifically, these are IPs that are referenced by Docker NAT rules, but are
# not associated with any running container.
prospective_bad_ips() {
  record_all_container_ips
  record_nat_ips

  for nat_ip in $(cat nat_ips.txt)
  do
    if ! grep "${nat_ip}" all_container_ips.txt >/dev/null 2>&1
    then
      echo "${nat_ip}"
    fi
  done
}

# Get a list of container IP addresses that are unreachable
#
# Specifically, of the prospective_bad_ips, list any IP that does not respond
# to a ping request.
bad_ips() {
  for prospect in $(prospective_bad_ips)
  do
    if ! ping -c 1 -w 1 "${prospect}" >/dev/null 2>&1
    then
      echo "${prospect}"
    fi
  done
}

# Find the IP addresses referenced by the Docker NAT rules for a given port
#
# Example:
#
#   ips_for_port 8080
ips_for_port() {
  if ! defined "${1}"
  then
    echo "no port passed to ips_for_port" >&2
    return 1
  fi

  ipt -t nat -S DOCKER | grep ":${1}" | awk '{print $NF}' | cut -d : -f 1
}

# List out the NAT rules associated with a given IP
#
# Example:
#
#   rules_for_ip 127.0.0.1
rules_for_ip() {
  if ! defined "${1}"
  then
    echo "no IP passed to rules_for_ip" >&2
    return 1
  fi

  local bad_ip="${1}"
  local nat_rule=""
  
  ipt -t nat -S | grep "${bad_ip}" | while read nat_rule
  do
    echo "-t nat ${nat_rule}"
  done
  ipt -S | grep "${bad_ip}"
}

# Given an existing firewall rule, remove that rule from the firewall
#
# The rule must be expressed exactly as it is listed via `iptables` with the
# '-S' flag.
#
# Example:
#
#   delete_rule -A SOMETHING -d 10.244.0.0/16 -j ACCEPT
delete_rule() {
  if ! defined "${@}"
  then
    echo "nothing passed to delete_rule" >&2
    return 1
  fi

  echo "Deleting rule '${@}'"
  ipt $(echo "${@}" | sed -e 's/-A /-D /')
}

#-------------------------------------------------------------------------------
#  Application Helpers
#-------------------------------------------------------------------------------

# Get a list of all applications known to the cluster
known_app_names() {
  local app=""

  for app in $(etcdctl ls /deis/config)
  do
    basename ${app}
  done | sort
}

# Get a list of all domains for all applications, grouped by application name
domains_by_app() {
  local domain=""

  for domain in $(etcdctl ls /deis/domains)
  do 
    echo "$(etcdctl get ${domain}): $(basename ${domain})"
  done | sort
}

# Get a list of all domains for a specific application
#
# The provided application name *must* be given in its canonical form, as the
# `grep` call used for this is case-sensitive and does not allow for pattern
# matching.
#
# Example:
#
#   domains_for my-awesome-application
domains_for() {
  if ! defined "${1}"
  then
    echo "USAGE: domain_for APP_NAME" >&2
    return 1
  fi

  domains_by_app | grep "${1}:" | awk '{print $NF}'
}
