FROM debian:bookworm

ENV PG_VERSION="1.16.1-1"

RUN apt update && apt upgrade -y && apt install -y pgbouncer=$PG_VERSION

COPY entrypoint.sh /entrypoint.sh
# postgres user needs permission for /etc/pgbouncer so that the entrypoint script can write
# the config file
RUN chown -R postgres /etc/pgbouncer
# need to remove already included pgbouncer.ini for entrypoint to create new config file based
# on the container environment variables
RUN rm /etc/pgbouncer/pgbouncer.ini

USER postgres
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
