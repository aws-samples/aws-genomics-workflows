import * as cdk from "@aws-cdk/core";
import * as batch from "@aws-cdk/aws-batch";
import * as sfn from "@aws-cdk/aws-stepfunctions";
import * as iam from "@aws-cdk/aws-iam";
import * as jobDefinitions from "./job-definitions";
import GenomicsTask from "./genomics-task-construct";
import GenomicsJobDefinition from "./job-definition-construct";
import * as config from "../../app.config.json";

export interface GenomicsStateMachineProps {
  readonly genomicsDefaultQueue: batch.JobQueue;
  readonly genomicsHighPriorityQueue: batch.JobQueue;
  readonly env: cdk.ResourceEnvironment;
  readonly taskRole: iam.Role;
}

export default class GenomicsStateMachine extends cdk.Stack {
  constructor(
    scope: cdk.Construct,
    id: string,
    props: GenomicsStateMachineProps
  ) {
    super(scope, id, { env: props.env });

    const jobDefinitionProps = {
      env: props.env,
      stack: this,
      jobRole: props.taskRole,
    };

    const fastQC = new jobDefinitions.FastQcJobDefinition({
      ...jobDefinitionProps,
      ...config.stepFunctions.jobDefinitions.fastqc,
    });

    const minimap2 = new jobDefinitions.Minimap2JObDefinition({
      ...jobDefinitionProps,
      ...config.stepFunctions.jobDefinitions.minimap2,
    });

    const step1TaskProps = {
      taskName: "FASTQC",
      environment: {
        JOB_INPUTS: sfn.JsonPath.stringAt("$.params.fastqc.input"),
        JOB_OUTPUTS: sfn.JsonPath.stringAt("$.params.fastqc.output"),
      },
      command: ["fastqc *.gz"],
      jobDefinition: new GenomicsJobDefinition(
        this,
        fastQC.jobDefinitionName,
        fastQC
      ).jobDefinition,
      queue: config.stepFunctions.jobDefinitions.fastqc.spot === true
        ? props.genomicsDefaultQueue
        : props.genomicsHighPriorityQueue,
    };

    const step1Task = new GenomicsTask(
      this,
      step1TaskProps.taskName,
      step1TaskProps
    ).task;

    const step2TaskProps = {
      taskName: "MINIMAP2",
      environment: {
        JOB_INPUTS: sfn.JsonPath.stringAt("$.params.minimap2.input"),
        FASTA_INPUT: sfn.JsonPath.stringAt("$.params.minimap2.fastaFileName"),
        FASTQ_INPUT: sfn.JsonPath.stringAt("$.params.minimap2.fastqFiles"),
        SAM_OUTPUT: sfn.JsonPath.stringAt("$.params.minimap2.samOutput"),
        JOB_OUTPUTS: sfn.JsonPath.stringAt("$.params.minimap2.output"),
      },
      command: ["minimap2 -ax map-pb $FASTA_INPUT $FASTQ_INPUT > $SAM_OUTPUT"],
      jobDefinition: new GenomicsJobDefinition(
        this,
        minimap2.jobDefinitionName,
        minimap2
      ).jobDefinition,
      queue: config.stepFunctions.jobDefinitions.minimap2.spot === true
        ? props.genomicsDefaultQueue
        : props.genomicsHighPriorityQueue,
    };

    const step2Task = new GenomicsTask(
      this,
      step2TaskProps.taskName,
      step2TaskProps
    ).task;

    const definition = step1Task.next(step2Task);

    const stateMachineProps = {
      definition,
      stateMachineName: "genomics-pipelines-state-machine",
      timeout: cdk.Duration.hours(1),
    };

    new sfn.StateMachine(
      this,
      stateMachineProps.stateMachineName,
      stateMachineProps
    );
  }
}
