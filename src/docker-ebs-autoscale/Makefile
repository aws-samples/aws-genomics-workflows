all: package upload
package:
	tar -cpvzf docker-ebs-autoscale.tar.gz  --exclude=".*" docker-ebs-autoscale/
upload:
	aws s3 cp docker-ebs-autoscale.tar.gz s3://angelfiles/docker-ebs-autoscale.tar.gz
