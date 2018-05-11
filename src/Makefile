all:  upload-bootstrap-scripts package-docker-ebs-autoscale upload-docker-ebs-autoscale

upload-bootstrap-scripts:
	aws s3 cp --acl public-read  create-scratch-space.sh s3://cromwell-aws-batch/files/
	aws s3 cp --acl public-read custom-ami-bootstrap-userdata.txt s3://cromwell-aws-batch/files/
	aws s3 cp --acl public-read  custom-ami-bootstrap.sh s3://cromwell-aws-batch/files/
package-docker-ebs-autoscale:
	tar -cpvzf docker-ebs-autoscale.tar.gz --exclude=".*"  docker-ebs-autoscale/
upload-docker-ebs-autoscale:
	aws s3 cp --acl public-read docker-ebs-autoscale.tar.gz s3://cromwell-aws-batch/files/docker-ebs-autoscale.tar.gz
