 #!/bin/bash

KUBECTL=/usr/bin/kubectl
PGPASSWORD=$($KUBECTL get secret --namespace default ${1}-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode; echo)

function usage() {
	echo "Usage: $0 <release-name> <init [scaling-factor] | bench [transactions] [clients] | shell | kill-and-move>"
}

if [ $# -lt 2 ]
then
	echo "You must supply a release and command"
	usage
fi

case "$2" in
	init)
		size=${3:-100}
		read -r -d '' COMMAND <<-EOF
			$KUBECTL run --namespace default ${1}-postgresql-pgbench-init \
			--restart=Never --rm --tty -i \
			--image postgres --env "PGPASSWORD=$PGPASSWORD"  \
			--command -- pgbench -i -s $size -U postgres  -h ${1}-postgresql postgres
		EOF
	;;
	shell)
		read -r -d '' COMMAND <<-EOF
			$KUBECTL run --namespace default ${1}-postgresql-pgbench-shell \
			--restart=Never --rm --tty -i \
			--image postgres --env "PGPASSWORD=$PGPASSWORD"  \
			--command -- psql -U postgres  -h ${1}-postgresql postgres
		EOF
	;;
	bench)
		transactions=${3:-5000}
		clients=${4:-80}
		read -r -d '' COMMAND <<-EOF
			$KUBECTL run --namespace default ${1}-postgresql-pgbench \
			--restart=Never --rm --tty -i \
			--image postgres --env "PGPASSWORD=$PGPASSWORD"  \
			--command -- pgbench -c $clients -t $transactions -U postgres  -h ${1}-postgresql postgres
		EOF
	;;
	kill-and-move)
		NODE=`$KUBECTL get pods -o wide | grep ${1}-postgresql | awk '{print $7}'`
		POD=`$KUBECTL get pods -o wide | grep ${1}-postgresql | awk '{print $1}'`
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
