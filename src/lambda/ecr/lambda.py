# /*********************************************************************************************************************
# *  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.                                                *
# *                                                                                                                    *
# *  Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance    *
# *  with the License. A copy of the License is located at                                                             *
# *                                                                                                                    *
# *      http://www.apache.org/licenses/LICENSE-2.0                                                                    *
# *                                                                                                                    *
# *  or in the 'license' file accompanying this file. This file is distributed on an 'AS IS' BASIS, WITHOUT WARRANTIES *
# *  OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions    *
# *  and limitations under the License.                                                                                *
# *********************************************************************************************************************/

from time import sleep

import boto3
import cfnresponse


send, SUCCESS, FAILED = (
    cfnresponse.send, 
    cfnresponse.SUCCESS, 
    cfnresponse.FAILED
)
ecr = boto3.client('ecr')


def wait(repo, until):
    until = until.lower()
    if until == "deleted":
        while True:
            try:
                sleep(1)
                ecr.describe_repositories(repositoryNames=[repo])
            except ecr.exceptions.RepositoryNotFoundException:
                break
    
    if until == "exists":
        exists = False
        while not exists:
            try:
                sleep(1)
                exists = ecr.describe_repositories(repositoryNames=[repo])["repositories"]
                break
            except ecr.exceptions.RepositoryNotFoundException:
                exists = False



def put_lifecycle_policy(repo, props):
    if props.get("LifecyclePolicy"):
        ecr.put_lifecycle_policy(
            repositoryName=repo,
            lifecyclePolicyText=props["LifecyclePolicy"]["LifecyclePolicyText"]
        )


def create(repo, props, event, context):
    # use existing repository if available, otherwise create
    try:
        ecr.create_repository(repositoryName=repo)
        wait(repo, "exists")
        put_lifecycle_policy(repo, props)
        
    except ecr.exceptions.RepositoryAlreadyExistsException:
        print(f"Repository '{repo}' already exists - CREATE ECR repository ignored")
        put_lifecycle_policy(repo, props)
        
    except Exception as e:
        send(event, context, FAILED, None)
        raise(e)


def update(repo, props, event, context):
    # use existing repository if available
    update_policy = props.get("UpdateReplacePolicy")
    try:
        if update_policy and update_policy.lower() == "retain":
            put_lifecycle_policy(repo, props)
        else:
            # replace the repo
            delete(repo, props, event, context)
            create(repo, props, event, context)
    except Exception as e:
        send(event, context, FAILED, None)
        raise(e)


def delete(repo, props, event, context):
    # retain repository if specified
    # otherwise force delete
    delete_policy = props.get("DeletePolicy")
    try:
        if delete_policy and not delete_policy.lower() == "retain":
            ecr.delete_repository(repositoryName=repo, force=True)
            wait(repo, "deleted")
    
    except Exception as e:
        send(event, context, FAILED, None)
        raise(e)


def handler(event, context):
    props = event["ResourceProperties"]
    repo = props.get("RepositoryName")
    
    if event["RequestType"] in ("Create", "Update", "Delete"):
        action = globals()[event["RequestType"].lower()]
        action(repo, props, event, context)
        send(event, context, SUCCESS, None)
    else:
        # unhandled request type
        send(event, context, FAILED, None)