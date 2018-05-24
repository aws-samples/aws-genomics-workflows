all:  upload-bootstrap-scripts

upload-bootstrap-scripts:
	aws s3 cp --acl public-read custom-ami-bootstrap-userdata.txt s3://cromwell-aws-batch/files/
	aws s3 cp --acl public-read  custom-ami-bootstrap.sh s3://cromwell-aws-batch/files/
	aws s3 cp --acl public-read  create-custom-ami.py s3://cromwell-aws-batch/files/
