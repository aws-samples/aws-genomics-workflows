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

from __future__ import print_function
from crhelper import CfnResource
import logging
import boto3
import time

logger = logging.getLogger(__name__)
# Initialise the helper, all inputs are optional, this example shows the defaults
helper = CfnResource(json_logging=False, log_level='DEBUG', boto_level='CRITICAL')

try:
    codebuild = boto3.client('codebuild')
    # pass
except Exception as e:
    helper.init_failure(e)


@helper.create
def create(event, context):
    logger.info("Got Create")
    start_build_job(event, context)


@helper.update
def update(event, context):
    logger.info("Got Update")
    start_build_job(event, context)


@helper.delete
def delete(event, context):
    logger.info("Got Delete")
    # Delete never returns anything. Should not fail if the underlying resources are already deleted. Desired state.


@helper.poll_create
def poll_create(event, context):
    logger.info("Got Create poll")
    return check_build_job_status(event, context)


@helper.poll_update
def poll_update(event, context):
    logger.info("Got Update poll")
    return check_build_job_status(event, context)


def handler(event, context):
    helper(event, context)


def start_build_job(event, context, action='setup'):
    response = codebuild.start_build(
        projectName=event['ResourceProperties']['BuildProject']
    )
    logger.info(response)
    helper.Data.update({"JobID": response['build']['id']})


def check_build_job_status(event, context):
    code_build_project_name = event['ResourceProperties']['BuildProject']

    if not helper.Data.get("JobID"):
        raise ValueError("Job ID missing in the polling event.")

    job_id = helper.Data.get("JobID")

    # 'SUCCEEDED' | 'FAILED' | 'FAULT' | 'TIMED_OUT' | 'IN_PROGRESS' | 'STOPPED'
    response = codebuild.batch_get_builds(ids=[job_id])
    build_status = response['builds'][0]['buildStatus']

    if build_status == 'IN_PROGRESS':
        logger.info(build_status)
        return None
    else:
        if build_status == 'SUCCEEDED':
            logger.info(build_status)
            return True
        else:
            msg = "Code Build job '{0}' in project '{1}' exited with a build status of '{2}'." \
                .format(job_id, code_build_project_name, build_status)
            logger.info(msg)
            raise ValueError(msg)
