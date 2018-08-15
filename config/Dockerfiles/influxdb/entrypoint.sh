#!/bin/bash
set -e


# Generate passwd file based on current uid
function generate_passwd_file() {
  USER_ID=$(id -u)
  GROUP_ID=$(id -g)

  if [ x"$USER_ID" != x"0" ]; then

    echo "default:x:${USER_ID}:${GROUP_ID}:Default Application User:${HOME}:/sbin/nologin" >> /etc/passwd

  fi
}

generate_passwd_file

if [ "${1:0:1}" = '-' ]; then
    set -- influxd "$@"
fi

if [ "$1" = 'influxd' ]; then
	/init-influxdb.sh "${@:2}"
fi

exec "$@"
