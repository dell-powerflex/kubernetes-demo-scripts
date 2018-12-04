#!/bin/bash

KUBECTL=/usr/bin/kubectl

function usage() {
	echo "Usage: $0 <release-name> <init [transactions] [threads] | bench [transactions] [threads] | shell | kill-and-move>"
}

if [ $# -lt 2 ]
then
	echo "You must supply a release and command"
	usage
fi

case "$2" in
	init)
		transactions=${3:-100000}
		threads=${4:-64}
		read -r -d '' COMMAND <<-EOF
			$KUBECTL run --namespace default ${1}-cassandra-stress-init \
			--restart=Never --rm --tty -i \
			--image cassandra \
			--command -- cassandra-stress write n=$transactions -rate threads=$threads -node ${1}-cassandra
		EOF
	;;
	shell)
		read -r -d '' COMMAND <<-EOF
			$KUBECTL run --namespace default ${1}-cassandra-stress-shell \
			--restart=Never --rm --tty -i \
			--image cassandra \
			--command -- cqlsh ${1}-cassandra
		EOF
	;;
	bench)
		transactions=${3:-100000}
		threads=${4:-64}
		read -r -d '' COMMAND <<-EOF
			$KUBECTL run --namespace default ${1}-cassandra-stress-bench \
			--restart=Never --rm --tty -i \
			--image cassandra \
			--command -- cassandra-stress read n=$transactions -rate threads=$threads -node ${1}-cassandra
		EOF
	;;
	kill-and-move)
		NODE=`$KUBECTL get pods -o wide | grep ${1}-cassandra-0 | awk '{print $7}'`
		POD=`$KUBECTL get pods -o wide | grep ${1}-cassandra-0 | awk '{print $1}'`
		read -r -d '' COMMAND <<-EOF
			$KUBECTL taint node $NODE key=value:NoSchedule && $KUBECTL delete pod $POD
		EOF
	;;
	cleanup)
		read -r -d '' COMMAND <<-EOF
			$KUBECTL taint node --all key:NoSchedule-
		EOF
	;;
	*)
		usage
	;;

esac
echo $COMMAND
eval $COMMAND