FROM debian:bookworm

ENV PG_VERSION="1.17.0"

RUN apt update && apt upgrade -y && apt install -y pgbouncer=$PG_VERSION

COPY entrypoint.sh /entrypoint.sh
# need to remove already included pgbouncer.ini for entrypoint to create new config file based
# on the container environment variables
RUN rm /etc/pgbouncer/pgbouncer.ini

USER postgres
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/pgbouncer", "/tmp/pgbouncer.ini"]
