from time import sleep

import boto3
import cfnresponse

def handler(event, context):
    if event['RequestType'] in ("Create", "Update"):
        codebuild = boto3.client('codebuild')
        build = codebuild.start_build(
            projectName=event["ResourceProperties"]["BuildProject"]
        )['build']
                
        id = build['id']
        status = build['buildStatus']
        while status == 'IN_PROGRESS':
            sleep(10)
            build = codebuild.batch_get_builds(ids=[id])['builds'][0]
            status = build['buildStatus']
        
        if status != "SUCCEEDED":
            cfnresponse.send(event, context, cfnresponse.FAILED, None)
    
    cfnresponse.send(event, context, cfnresponse.SUCCESS, None)
