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

def create(repo, props, event, context):
    # use existing repository if available, otherwise create
    try:
        ecr.create_repository(
            repositoryName=repo
        )

        wait(repo, "exists")

        if repo.get("LifecyclePolicy"):
            ecr.put_lifecycle_policy(
                repositoryName=repo,
                lifecyclePolicyText=repo["LifecyclePolicy"]["LifecyclePolicyText"]
            )
        
    except ecr.exceptions.RepositoryAlreadyExistsException:
        print(f"Repository '{repo}' already exists - CREATE ignored")

    except Exception as e:
        send(event, context, FAILED, None)
        raise(e)

def update(repo, props, event, context):
    # use existing repository if available
    update_policy = props.get("UpdateReplacePolicy")
    try:
        if update_policy and update_policy.lower() == "retain":
            if repo.get("LifecyclePolicy"):
                ecr.put_lifecycle_policy(
                    repositoryName=repo,
                    lifecyclePolicyText=repo["LifecyclePolicy"]["LifecyclePolicyText"]
                )
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
    delete_policy = props.get("DetetePolicy")
    try:
        if delete_policy and not delete_policy.lower() == "retain":
            ecr.delete_repository(
                repositoryName=repo,
                force=True
            )

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
    