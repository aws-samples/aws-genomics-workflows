#!/bin/bash
aws --profile cromwell-on-aws \
    cloudformation create-stack \
    --stack-name CromwellServer \
    --template-body file://./cromwell-server.template.yaml \
    --capabilities CAPABILITY_IAM \
    --parameters \
        ParameterKey=VpcId,ParameterValue=vpc-0875235051b2b1f8a \
        ParameterKey=PublicSubnetID,ParameterValue=subnet-0c555a9cd255cfe55 \
        ParameterKey=KeyName,ParameterValue=pwyming \
        ParameterKey=S3BucketName,ParameterValue=aws-cromwell-test-us-west-2 \
        ParameterKey=BatchQueue,ParameterValue=arn:aws:batch:us-west-2:075756284674:job-queue/GenomicsDefaultQueue-6938bfa7d75c42c