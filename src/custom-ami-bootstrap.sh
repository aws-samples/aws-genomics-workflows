function printUsage() {
  #statements
  echo "USAGE: $0 <VOLUME GROUP NAME> <LOGICAL VOLUME NAME> <MOUNT POINT>"
}

if [ "$#" -ne "3" ]; then
  printUsage
  exit 1
fi
VG=$1
LV=$2
MP=$3

# download and install the /docker_scratch autoscale service
cd /tmp
curl -o ebs-autoscale.tar.gz http://cromwell-aws-batch.s3.amazonaws.com/files/ebs-autoscale.tar.gz
tar -xzf ebs-autoscale.tar.gz
sh /tmp/ebs-autoscale/bin/bootstrap-ebs-autoscale.sh ${VG} ${LV} ${MP} 2>&1 > /var/log/bootstrap-ebs-autoscale.log


# Configure task IP Tables if needed
COUNT=$(service iptables  status | grep 51679 | wc -l)
if [ "${COUNT}" -lt "2" ]; then
  sysctl -w net.ipv4.conf.all.route_localnet=1
  iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
  iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
  service iptables save
fi

# ECS agent stop
stop ecs
if [ -e /var/lib/ecs/data/ecs_agent_data.json ]; then
  rm -rf /var/lib/ecs/data/ecs_agent_data.json
fi

# clean up repository caches
yum clean all
