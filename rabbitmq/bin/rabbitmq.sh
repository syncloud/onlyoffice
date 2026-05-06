#!/bin/bash -e
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

export PATH=${DIR}/usr/lib/erlang/bin:$PATH
export ERL_LIBS=${DIR}/usr/lib/rabbitmq/lib

exec ${DIR}/usr/lib/rabbitmq/bin/rabbitmq-server "$@"
