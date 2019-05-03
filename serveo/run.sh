#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

ALIAS="$(jq --raw-output '.alias' $CONFIG_PATH)"
SERVER="$(jq --raw-output '.server' $CONFIG_PATH)"
SSH_PORT="$(jq --raw-output '.ssh_port' $CONFIG_PATH)"
DOMAIN="$(jq --raw-output '.domain' $CONFIG_PATH)"
PORT1FROM="$(jq --raw-output '.port1from' $CONFIG_PATH)"
PORT1TO="$(jq --raw-output '.port1to' $CONFIG_PATH)"
PORT2FROM="$(jq --raw-output '.port2from' $CONFIG_PATH)"
PORT2TO="$(jq --raw-output '.port2to' $CONFIG_PATH)"
PORT3FROM="$(jq --raw-output '.port3from' $CONFIG_PATH)"
PORT3TO="$(jq --raw-output '.port3to' $CONFIG_PATH)"
RETRY_TIME="$(jq --raw-output '.retry_time' $CONFIG_PATH)"
IDRSA="$(jq --raw-output '.id_rsa' $CONFIG_PATH)"

if [ "$ALIAS" == "" ]
then
  DOMAIN_PREFIX=""
  ALIAS_PREFIX=""
else
  DOMAIN_PREFIX="${ALIAS}."
  ALIAS_PREFIX="${ALIAS}@"
fi

if [ "$SSH_PORT" != "0" ]
then
  SSH_PORT_PARAM="-p $SSH_PORT"
else
  SSH_PORT_PARAM=""
fi

if [ "${DOMAIN}" != "" ]
then
    DOMAIN_PARAM="${DOMAIN}:"
else
    DOMAIN_PARAM=""
fi


PORT1="-R ${DOMAIN_PARAM}${PORT1TO}:localhost:${PORT1FROM}"
PORT2=""
PORT3=""


if [ "${PORT2FROM}" != "0" ] && ["${PORT2TO}" != "0"]
then
    PORT2=" -R ${DOMAIN_PARAM}${PORT2TO}:localhost:${PORT2FROM}"
fi

if [ "${PORT3FROM}" != "0" ] && ["${PORT3TO}" != "0"]
then
    PORT3=" -R  ${DOMAIN_PARAM}${PORT3TO}:localhost:${PORT3FROM}"
fi

if [ "$IDRSA" != "" ]
then
    if [ ! -d "/root/.ssh" ]; then
    mkdir "/root/.ssh"
    fi
    cp "$IDRSA" "/root/.ssh/id_rsa"
    chmod 600 "/root/.ssh/id_rsa"
fi


CMD="/bin/bash -c 'sleep ${RETRY_TIME} && ssh ${SSH_PORT_PARAM} -tt -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 ${PORT1}${PORT2}${PORT3} ${ALIAS_PREFIX}${SERVER}'"

echo "Running '${CMD}' through supervisor!"

cat > /etc/supervisor-docker.conf << EOL
[supervisord]
user=root
nodaemon=true
logfile=/dev/null
logfile_maxbytes=0
EOL
cat >> /etc/supervisor-docker.conf << EOL
[program:serveo]
command=${CMD}
autostart=true
autorestart=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
redirect_stderr=true
EOL

exec supervisord -c /etc/supervisor-docker.conf
