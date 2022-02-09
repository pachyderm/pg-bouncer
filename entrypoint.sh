#!/bin/sh
# Based on https://raw.githubusercontent.com/brainsam/pgbouncer/master/entrypoint.sh

set -e

print_validation_error() {
    error "$1"
    error_code=1
}

# Here are some parameters. See all on
# https://pgbouncer.github.io/config.html

PG_CONFIG_DIR=/etc/pgbouncer

# Write the password with MD5 encryption, to avoid printing it during startup.
# Notice that `docker inspect` will show unencrypted env variables.
_AUTH_FILE="${AUTH_FILE:-$PG_CONFIG_DIR/userlist.txt}"

# Workaround userlist.txt missing issue
# https://github.com/edoburu/docker-pgbouncer/issues/33
if [ ! -e "${_AUTH_FILE}" ]; then
    touch "${_AUTH_FILE}"
fi

pass="md5$(echo -n "$POSTGRESQL_PASSWORD$POSTGRESQL_USERNAME" | md5sum | cut -f 1 -d ' ')"
echo "\"$POSTGRESQL_USERNAME\" \"$pass\"" >> ${PG_CONFIG_DIR}/userlist.txt
echo "Wrote authentication credentials to ${PG_CONFIG_DIR}/userlist.txt"

# TLS Checks (server)
if [[ -n "$PGBOUNCER_SERVER_TLS_CERT_FILE" ]] && [[ ! -f "$PGBOUNCER_SERVER_TLS_CERT_FILE" ]]; then
    print_validation_error "The X.509 server certificate file in the specified path ${PGBOUNCER_SERVER_TLS_CERT_FILE} does not exist"
fi
if [[ -n "$PGBOUNCER_SERVER_TLS_KEY_FILE" ]] && [[ ! -f "$PGBOUNCER_SERVER_TLS_KEY_FILE" ]]; then
    print_validation_error "The server private key file in the specified path ${PGBOUNCER_SERVER_TLS_KEY_FILE} does not exist"
fi
if [[ -n "$PGBOUNCER_SERVER_TLS_CA_FILE" ]]; then
    warn "A CA X.509 certificate was not provided. Server verification will not be performed in TLS connections"
elif [[ ! -f "$PGBOUNCER_SERVER_TLS_CA_FILE" ]]; then
    print_validation_error "The server CA X.509 certificate file in the specified path ${PGBOUNCER_SERVER_TLS_CA_FILE} does not exist"
fi


if [ ! -f ${PG_CONFIG_DIR}/pgbouncer.ini ]; then
    echo "Create pgbouncer config in ${PG_CONFIG_DIR}"

    # Config file is in “ini” format. Section names are between “[” and “]”.
    # Lines starting with “;” or “#” are taken as comments and ignored.
    # The characters “;” and “#” are not recognized when they appear later in the line.
    printf "\
    ################## Auto generated ##################
    [databases]
    *=host=${POSTGRESQL_HOST:?"Setup pgbouncer config error! You must set DB_HOST env"} \
    port=${POSTGRESQL_PORT:-5432} user=${POSTGRESQL_USERNAME:-postgres}

    [pgbouncer]
    listen_addr = ${LISTEN_ADDR:-0.0.0.0}
    listen_port = ${LISTEN_PORT:-5432}
    auth_file = ${AUTH_FILE:-$PG_CONFIG_DIR/userlist.txt}
    auth_type = ${AUTH_TYPE:-md5}
    ${POOL_MODE:+pool_mode = ${POOL_MODE}\n}\
    ${MAX_CLIENT_CONN:+max_client_conn = ${MAX_CLIENT_CONN}\n}\
    ignore_startup_parameters = ${IGNORE_STARTUP_PARAMETERS:-extra_float_digits}
    admin_users = ${ADMIN_USERS:-postgres}
    ${IDLE_TRANSACTION_TIMEOUT:+idle_transaction_timeout = ${IDLE_TRANSACTION_TIMEOUT}\n}\

    # TLS settings
    ${CLIENT_TLS_SSLMODE:+client_tls_sslmode = ${CLIENT_TLS_SSLMODE}\n}\
    ${SERVER_TLS_SSLMODE:+server_tls_sslmode = ${SERVER_TLS_SSLMODE}\n}\
    ${PGBOUNCER_SERVER_TLS_CA_FILE:+server_tls_ca_file = ${PGBOUNCER_SERVER_TLS_CA_FILE}\n}\
    ${PGBOUNCER_SERVER_TLS_KEY_FILE:+server_tls_key_file = ${PGBOUNCER_SERVER_TLS_KEY_FILE}\n}\
    ${PGBOUNCER_SERVER_TLS_CERT_FILE:+server_tls_cert_file = ${PGBOUNCER_SERVER_TLS_CERT_FILE}\n}\
    ################## end file ##################
    " > ${PG_CONFIG_DIR}/pgbouncer.ini
    cat ${PG_CONFIG_DIR}/pgbouncer.ini
    echo "Starting $*..."
fi

exec "$@"