function printUsage() {
  echo "USAGE: $0 <MOUNT POINT> [<DEVICE NAME>]"
}

if [ "$#" -lt "1" ]; then
  printUsage
  exit 1
fi
MP=$1
DV=$2

# download and install the /docker_scratch autoscale service
cd /opt
curl -o ebs-autoscale.tar.gz http://cromwell-aws-batch.s3.amazonaws.com/files/ebs-autoscale.tar.gz
tar -xzf ebs-autoscale.tar.gz
rm -f  ebs-autoscale.tar.gz
sh /opt/ebs-autoscale/bin/init-ebs-autoscale.sh ${MP} ${DV} 2>&1 > /var/log/init-ebs-autoscale.log


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
