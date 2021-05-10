import * as cdk from "@aws-cdk/core";
import * as batch from "@aws-cdk/aws-batch";
import * as sfn from "@aws-cdk/aws-stepfunctions";
import * as tasks from "@aws-cdk/aws-stepfunctions-tasks";

export interface GenomicsTaskProps {
    readonly taskName: string;
    readonly command: string[];
    readonly jobDefinition: batch.JobDefinition;
    readonly queue: batch.JobQueue;
    readonly awsCliPath?: string;
    readonly environment?: { [key: string]: string };
}

export default class GenomicsTask extends cdk.Construct {
    
    public readonly task: tasks.BatchSubmitJob;
    
    constructor(scope: cdk.Construct, id: string, props: GenomicsTaskProps) {
        super(scope, id);
    
        const defaultEnvironment = {
            JOB_WORKFLOW_NAME: sfn.JsonPath.stringAt("$$.StateMachine.Name"),
            JOB_WORKFLOW_EXECUTION: sfn.JsonPath.stringAt("$$.Execution.Name"),
            JOB_OUTPUT_PREFIX: sfn.JsonPath.stringAt("$.params.environment.JOB_OUTPUT_PREFIX"),
            JOB_AWS_CLI_PATH: props.awsCliPath ?? "/opt/aws-cli/bin"
        }
        
        let environment;
        if(props.environment){
            environment = {...defaultEnvironment, ...props.environment};
        }
        else{
            environment = defaultEnvironment;
        }
    
        const taskContainerProps = {
          command: props.command,
          environment: environment
        };
        const taskProps = {
            jobName: props.taskName,
            jobDefinitionArn: props.jobDefinition.jobDefinitionArn,
            jobQueueArn: props.queue.jobQueueArn,
            containerOverrides: taskContainerProps,
            inputPath: "$",
            resultPath: "$.result"
        };
    
        this.task = new tasks.BatchSubmitJob(this, taskProps.jobName, taskProps);
    }
}