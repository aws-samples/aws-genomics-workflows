#!/bin/env python3
"""
Helper script to submit nextflow workflows to AWS Batch using batch-squared architecture and GWFCore
"""

import argparse
from datetime import datetime
from pprint import pprint
import re
import sys
from urllib.parse import urlparse

import boto3

parser = argparse.ArgumentParser(description="Run a Nextflow workflow on AWS.")
parser.add_argument('--region', type=str, help="AWS Region to use. (See 'aws configure')")
parser.add_argument('--profile', type=str, help="AWS Profile to use. (See 'aws configure')")
parser.add_argument('-v', '--verbose', action='store_true', help="print extra information")

subparsers = parser.add_subparsers(title="subcommands")
subparser_run = subparsers.add_parser("run", help="run a workflow")
subparser_run.add_argument('--gwfcore-namespace', type=str, default="gwfcore", help="GWFCore namespace to use for AWS Batch resources. (Default: %(default)s)")
subparser_run.add_argument('--nextflow-namespace', type=str, default="nextflow", help="Nextflow namespace to use for AWS Batch resources. (Default: %(default)s)")
subparser_run.add_argument('--workflow-name', type=str, help="Name to use for the workflow job. Defaults to 'nf-workflow-<project>' where <project> is a santized version of the project name provided as the workflow to run")
subparser_run.add_argument('project', type=str, help="Nextflow project (workflow) to run. (Example: nextflow-io/rnaseq-nf)")
subparser_run.add_argument('params', metavar="...", type=str, nargs=argparse.REMAINDER, help="optional parameters to provide to the engine or workflow. (Example: -with-tower -resume --param1 a --param2 b")

subparser_status = subparsers.add_parser("status", help="check on workflow status")
subparser_status.add_argument('jobid', type=str, help="Batch JobId of the nextflow job")

subparser_log = subparsers.add_parser("log", help="get workflow log")
subparser_log.add_argument('--step', type=str, help="Nextflow prefix/hash of the workflow step")
subparser_log.add_argument('jobid', type=str, help="Batch JobId of the nextflow job")

def run(args):
    session = boto3.Session(region_name=args.region, profile_name=args.profile)
    batch = session.client('batch')
    ssm = session.client('ssm')

    priority_queue = ssm.get_parameter(Name=f"/gwfcore/{args.gwfcore_namespace}/job-queue/priority")
    priority_queue = priority_queue['Parameter']['Value']

    job_name = f"nf-workflow-{args.project}"
    if args.workflow_name:
        job_name = args.workflow_name
    
    job_name = re.sub('[^\w-]', '-', job_name)
    if len(job_name) > 128:
        job_name = job_name[:128]

    command = [args.project] + args.params

    job_sub = {
        "jobName": job_name,
        "jobDefinition": f"nextflow-{args.nextflow_namespace}",
        "jobQueue": priority_queue,
        "containerOverrides": {
            "command": command
        }
    }

    if args.verbose:
        print(f"submission request: {job_sub}")

    response = batch.submit_job(**job_sub)

    if args.verbose:
        pprint(response)
    else:
        pprint({k:v for k, v in response.items() if k in ('jobArn', 'jobName', 'jobId')})


def status(args):
    session = boto3.Session(region_name=args.region, profile_name=args.profile)
    batch = session.client('batch')
    
    response = batch.describe_jobs(jobs=[args.jobid])
    if args.verbose:
        pprint(response)
    else:
        jobs = response['jobs']
        for job in jobs:
            j = {k:v for k, v in job.items() if k in ('jobArn', 'jobName', 'jobId', 'status', 'statusReason', 'createdAt', 'startedAt', 'stoppedAt')}
            for k in ('createdAt', 'startedAt', 'stoppedAt'):
                if j.get(k):
                    j[k] = datetime.utcfromtimestamp(int(j[k]) / 1000).strftime('%Y-%m-%d %H:%M:%S')
            pprint(j)


def log(args):
    session = boto3.Session(region_name=args.region, profile_name=args.profile)
    batch = session.client('batch')
    cwlogs = session.client('logs')

    response = batch.describe_jobs(jobs=[args.jobid])
    jobs = response['jobs']
    for job in jobs:
        if args.step:
            step(session, job, args.step)
        else:
            try:
                log_stream_name = job['container']['logStreamName']
                response = cwlogs.get_log_events(logGroupName="/aws/batch/job", logStreamName=log_stream_name)
                events = response['events']

                for event in events:
                    ts = datetime.utcfromtimestamp(event['timestamp']/1000).strftime('%Y-%m-%d %H:%M:%S')
                    print(f"[{ts}] {event['message']}")
            except (KeyError, cwlogs.exceptions.ResourceNotFoundException):
                print("No log found. Either the job has not started yet or there was an error.")


def step(session, job, step_id):
    s3 = session.resource('s3')

    environment = job['container']['environment']
    nf_workdir = None
    for e in environment:
        if e['name'] == "NF_WORKDIR":
            nf_workdir = e['value']
            break
    
    uri = urlparse(nf_workdir)
    bucket = uri.netloc
    prefix = "/".join([uri.path[1:], step_id])

    bucket = s3.Bucket(bucket)
    objs = bucket.objects.filter(Prefix=prefix)
    step_log = None
    for o in objs:
        if o.key.endswith("/.command.log"):
            obj = s3.Object(o.bucket_name, o.key)
            step_log = obj.get()['Body'].read().decode('utf8')
            break
    
    if step_log:
        print(step_log)



subparser_run.set_defaults(func=run)
subparser_status.set_defaults(func=status)
subparser_log.set_defaults(func=log)

if __name__ == "__main__" :
    args = parser.parse_args()
    try:
        args.func(args)
    except AttributeError:
        parser.print_help(sys.stderr)
        sys.exit(1)