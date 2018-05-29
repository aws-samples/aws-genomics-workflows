all:  upload-bootstrap-scripts

upload-bootstrap-scripts:
	aws s3 cp --acl public-read genomics-ami-userdata.txt s3://cromwell-aws-batch/files/
	aws s3 cp --acl public-read  genomics-ami-bootstrap.sh s3://cromwell-aws-batch/files/
	aws s3 cp --acl public-read  create-genomics-ami.py s3://cromwell-aws-batch/files/
