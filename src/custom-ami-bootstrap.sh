# download and install the /docker_scratch autoscale service
cd /opt
curl -o ebs-autoscale.tar.gz http://cromwell-aws-batch/files/ebs-autoscale.tar.gz
tar -xzf ebs-autoscale.tar.gz
sh /opt/ebs-autoscale/bin/bootstrap-ebs-autoscale.sh  docker_scratch docker_scratch_pool /var/lib/docker/volumes/

# Configure task IP Tables
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
service iptables save

# ECS agent stop
if [ -e /var/lib/ecs/data/ecs_agent_data.json ]; then
  stop ecs
  rm -rf /var/lib/ecs/data/ecs_agent_data.json
fi

# clean up repository caches
yum clean all
