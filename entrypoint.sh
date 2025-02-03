#!/bin/sh -e
# Based on https://raw.githubusercontent.com/brainsam/pgbouncer/master/entrypoint.sh

set -e

# Here are some parameters. See all on
# https://pgbouncer.github.io/config.html

PG_CONFIG_DIR=/etc/pgbouncer

if [ -n "$DATABASE_URL" ]; then
  # Thanks to https://stackoverflow.com/a/17287984/146289

  # Allow to pass values like dj-database-url / django-environ accept
  proto="$(echo $DATABASE_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  url="$(echo $DATABASE_URL | sed -e s,$proto,,g)"

  # extract the user and password (if any)
  userpass=$(echo $url | grep @ | sed -r 's/^(.*)@([^@]*)$/\1/')
  DB_PASSWORD="$(echo $userpass | grep : | cut -d: -f2)"
  if [ -n "$DB_PASSWORD" ]; then
    DB_USER=$(echo $userpass | grep : | cut -d: -f1)
  else
    DB_USER=$userpass
  fi

  # extract the host -- updated
  hostport=`echo $url | sed -e s,$userpass@,,g | cut -d/ -f1`
  port=`echo $hostport | grep : | cut -d: -f2`
  if [ -n "$port" ]; then
      DB_HOST=`echo $hostport | grep : | cut -d: -f1`
      DB_PORT=$port
  else
      DB_HOST=$hostport
  fi

  DB_NAME="$(echo $url | grep / | cut -d/ -f2-)"
fi

if [ -z "${POOL_MODE}" ]; then
  echo "Error: POOL_MODE is not set"
  exit 1
fi

if [ -z "${WEB_POOL_SIZE}" ]; then
  echo "Error: WEB_POOL_SIZE is not set"
  exit 1
fi

if [ -z "${JOB_POOL_SIZE}" ]; then
  echo "Error: JOB_POOL_SIZE is not set"
  exit 1
fi

if [ -z "${CONSOLE_POOL_SIZE}" ]; then
  echo "Error: CONSOLE_POOL_SIZE is not set"
  exit 1
fi

if [ -z "${DB_HOST}" ]; then
  echo "Error: DB_HOST is not set"
  exit 1
fi

if [ -z "${DB_PORT}" ]; then
  echo "Error: DB_PORT is not set"
  exit 1
fi

if [ -z "${DB_USER}" ]; then
  echo "Error: DB_USER is not set"
  exit 1
fi

if [ -z "${DB_NAME}" ]; then
  echo "Error: DB_NAME is not set"
  exit 1
fi

if [ -z "${PORT}" ]; then
  echo "Error: PORT is not set"
  exit 1
fi


# Write the password with MD5 encryption, to avoid printing it during startup.
# Notice that `docker inspect` will show unencrypted env variables.
_AUTH_FILE="${AUTH_FILE:-$PG_CONFIG_DIR/userlist.txt}"

# Workaround userlist.txt missing issue
# https://github.com/edoburu/docker-pgbouncer/issues/33
if [ ! -e "${_AUTH_FILE}" ]; then
  touch "${_AUTH_FILE}"
fi

if [ -n "$DB_USER" -a -n "$DB_PASSWORD" -a -e "${_AUTH_FILE}" ] && ! grep -q "^\"$DB_USER\"" "${_AUTH_FILE}"; then
  if [ "$AUTH_TYPE" != "plain" ]; then
     pass="md5$(echo -n "$DB_PASSWORD$DB_USER" | md5sum | cut -f 1 -d ' ')"
  else
     pass="$DB_PASSWORD"
  fi
  pass="$DB_PASSWORD"
  echo "\"$DB_USER\" \"$pass\"" >> ${PG_CONFIG_DIR}/userlist.txt
  echo "Wrote authentication credentials to ${PG_CONFIG_DIR}/userlist.txt"
fi

sed -e "s/\${DB_HOST}/$DB_HOST/g" \
    -e "s/\${DB_NAME}/$DB_NAME/g" \
    -e "s/\${DB_PORT}/$DB_PORT/g" \
    -e "s/\${DB_USER}/$DB_USER/g" \
    -e "s/\${POOL_MODE}/$POOL_MODE/g" \
    -e "s/\${WEB_POOL_SIZE}/$WEB_POOL_SIZE/g" \
    -e "s/\${JOB_POOL_SIZE}/$JOB_POOL_SIZE/g" \
    -e "s/\${CONSOLE_POOL_SIZE}/$CONSOLE_POOL_SIZE/g" \
    -e "s/\${PORT}/$PORT/g" \
    ${PG_CONFIG_DIR}/pgbouncer.ini.template > ${PG_CONFIG_DIR}/pgbouncer.ini

cat ${PG_CONFIG_DIR}/pgbouncer.ini
echo "Starting $*..."

exec "$@"
