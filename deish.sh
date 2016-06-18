defined() {
  [ -n "${1}" ]
}

i_am_groot() {
  [ "$(whoami)" = 'root' ]
}

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

container_names() {
  docker ps | awk '{print $NF}' | grep -v 'NAMES'
}

container_ip() {
  local container=$1
  docker inspect "${container}" | grep '"IPAddress"' | awk '{print $NF}' | sed -e 's/"//g' | sed -e 's/,//g'
}

container_ips() {
  local container=""

  for container in $(container_names)
  do
    container_ip "${container}"
  done | sort | uniq
}

record_container_ips() {
  container_ips > container_ips.txt
}

nat_ips() {
  ipt -t nat -S DOCKER | awk '{print $NF}' | grep -v 'DOCKER' | cut -d : -f 1 | sort | uniq
}

record_nat_ips() {
  nat_ips > nat_ips.txt
}

prospective_bad_ips() {
  record_container_ips
  record_nat_ips

  for nat_ip in $(cat nat_ips.txt)
  do
    if ! grep "${nat_ip}" container_ips.txt >/dev/null 2>&1
    then
      echo "${nat_ip}"
    fi
  done
}

bad_ips() {
  for prospect in $(prospective_bad_ips)
  do
    if ! ping -c 1 -w 1 "${prospect}" >/dev/null 2>&1
    then
      echo "${prospect}"
    fi
  done
}

ips_for_port() {
  if ! defined "${1}"
  then
    echo "no port passed to ips_for_port" >&2
    return 1
  fi

  ipt -t nat -S DOCKER | grep ":${1}" | awk '{print $NF}' | cut -d : -f 1
}

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

delete_rule() {
  if ! defined "${@}"
  then
    echo "nothing passed to delete_rule" >&2
    return 1
  fi

  echo "Deleting rule '${@}'"
  ipt $(echo "${@}" | sed -e 's/-A /-D /')
}
