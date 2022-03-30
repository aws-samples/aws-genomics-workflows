import * as cdk from "@aws-cdk/core";
import * as batch from "@aws-cdk/aws-batch";
import * as sfn from "@aws-cdk/aws-stepfunctions";
import * as iam from "@aws-cdk/aws-iam";
import * as jobDefinitions from "./job-definitions";
import * as tasks from "@aws-cdk/aws-stepfunctions-tasks";
import GenomicsTask from "./genomics-task-construct";
import GenomicsJobDefinition from "./job-definition-construct";

export interface GenomicsStateMachineProps {
  readonly stackProps: cdk.StackProps;
  readonly batchQueue: batch.JobQueue;
  readonly taskRole: iam.Role;
}

/**
 * A stack for variant calling using GATK HaplotypeCaller
 * The stack will set the following pipeline:
 * FastQC -> bwa mem -> samtools sort -> samtools index -> GATK HaplotypeCaller
 *
 * The result for each step will be stage via S3 and will be used for the next
 * step of the pipeline.
 *
 * The final output will be a realigned reads stored in a bam file on S3
 *
 **/
export default class VariantCallingStateMachine extends cdk.Stack {
  getTimeout(defs: jobDefinitions.JobDefinitionBase[]): number {
    let result: number = 0;
    for (let i = 0; i < defs.length; i++) {
      result += (defs[i].timeout ?? 3600) * (defs[i].retryAttempts ?? 1);
    }
    return result;
  }

  constructor(
    scope: cdk.Construct,
    id: string,
    props: GenomicsStateMachineProps
  ) {
    super(scope, id, props.stackProps);

    // Default properties for initializing a job definition class
    const defaultJobDefinitionProps = {
      env: props.stackProps.env as cdk.ResourceEnvironment,
      stack: this,
      jobRole: props.taskRole,
    };

    // Initialzing a job definition for the gatk tool to run create dictionary
    // This won't be used as part of the pipeline but just create a batch job
    // definition that can be used to create a dictionary to reference databases
    const gatkCreateDisctionary = new jobDefinitions.GatkJObDefinition({
      ...defaultJobDefinitionProps,
      repository: "genomics/gatk",
      timeout: 600,
      memoryLimit: 8000,
      vcpus: 4,
    });

    new GenomicsJobDefinition(
      this,
      `${gatkCreateDisctionary.jobDefinitionName}CreateSequenceDictionary`,
      gatkCreateDisctionary
    );

    // Initialzie a job definition for the FastQC tool
    const fastQC = new jobDefinitions.FastQcJobDefinition({
      ...defaultJobDefinitionProps,
      repository: "genomics/fastqc",
      timeout: 600,
      memoryLimit: 1000,
      vcpus: 1,
    });

    // Initilalize a job definitiion for the BWA tool to run bwa mem
    const bwaMem = new jobDefinitions.BwaJObDefinition({
      ...defaultJobDefinitionProps,
      repository: "genomics/bwa",
      timeout: 600,
      memoryLimit: 32000,
      vcpus: 8,
    });

    // Initilalize a job definitiion for the sam tool to run samtools sort
    const samToolsSort = new jobDefinitions.SamToolsJObDefinition({
      ...defaultJobDefinitionProps,
      repository: "genomics/samtools",
      timeout: 300,
      memoryLimit: 8000,
      vcpus: 4,
    });

    // Initilalize a job definitiion for the sam tool to run samtools index
    const samToolsIndex = new jobDefinitions.SamToolsJObDefinition({
      ...defaultJobDefinitionProps,
      repository: "genomics/samtools",
      timeout: 300,
      memoryLimit: 1000,
      vcpus: 1,
    });

    // Initialize a job definition for the picard tool to add missing groups
    const picardAddMissingGroups = new jobDefinitions.PicardJObDefinition({
      ...defaultJobDefinitionProps,
      repository: "genomics/picard",
      timeout: 600,
      memoryLimit: 8000,
      vcpus: 4,
    });

    // Initilalize a job definitiion for the gatk tool to run gatk HaplotypeCaller
    const gatkHaplotypeCaller = new jobDefinitions.GatkJObDefinition({
      ...defaultJobDefinitionProps,
      repository: "genomics/gatk",
      timeout: 3600,
      memoryLimit: 16000,
      vcpus: 8,
    });

    // Set the total timeout for the entire execution
    const totalTimeout = this.getTimeout([
      fastQC,
      bwaMem,
      samToolsSort,
      samToolsIndex,
      gatkHaplotypeCaller,
    ]);

    // Set the first task to FastQC
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
      queue: props.batchQueue,
    };

    const step1Task = new GenomicsTask(
      this,
      step1TaskProps.taskName,
      step1TaskProps
    ).task;

    // Set the second task to bwa mem
    const step2TaskProps = {
      taskName: "BWAMEM",
      environment: {
        JOB_INPUTS: sfn.JsonPath.stringAt("$.params.bwa.input"),
        SAMPLE_ID: sfn.JsonPath.stringAt("$.params.common.sampleId"),
        REFERENCE_NAME: sfn.JsonPath.stringAt("$.params.common.referenceName"),
        JOB_OUTPUTS: sfn.JsonPath.stringAt("$.params.bwa.output"),
      },
      command: [
        "bwa mem -t 8 -p ",
        " -o ${SAMPLE_ID}.sam ${REFERENCE_NAME}.fasta ${SAMPLE_ID}_*1*.fastq.gz"
      ],
      jobDefinition: new GenomicsJobDefinition(
        this,
        bwaMem.jobDefinitionName,
        bwaMem
      ).jobDefinition,
      queue: props.batchQueue,
    };

    const step2Task = new GenomicsTask(
      this,
      step2TaskProps.taskName,
      step2TaskProps
    ).task;

    // Set the third task to samtools sort
    const step3TaskProps = {
      taskName: "SAMTOOLS-SORT",
      environment: {
        JOB_INPUTS: sfn.JsonPath.stringAt("$.params.samtoolsSort.input"),
        SAMPLE_ID: sfn.JsonPath.stringAt("$.params.common.sampleId"),
        JOB_OUTPUTS: sfn.JsonPath.stringAt("$.params.samtoolsSort.output"),
      },
      command: ["samtools sort -@ 4 -o ${SAMPLE_ID}.bam ${SAMPLE_ID}.sam"],
      jobDefinition: new GenomicsJobDefinition(
        this,
        `${samToolsSort.jobDefinitionName}Sort`,
        samToolsSort
      ).jobDefinition,
      queue: props.batchQueue,
    };

    const step3Task = new GenomicsTask(
      this,
      step3TaskProps.taskName,
      step3TaskProps
    ).task;

    // set the forth task to picard AddOrReplaceReadGroups
    const step4TaskProps = {
      taskName: "PICARD-ADDMISSINGGROUPS",
      environment: {
        JOB_INPUTS: sfn.JsonPath.stringAt("$.params.picard.input"),
        SAMPLE_ID: sfn.JsonPath.stringAt("$.params.common.sampleId"),
        JOB_OUTPUTS: sfn.JsonPath.stringAt("$.params.picard.output"),
      },
      command: [
        "java -jar /usr/picard/picard.jar AddOrReplaceReadGroups",
        " -I ${SAMPLE_ID}.bam -O ${SAMPLE_ID}.rg.bam -RGID 4 --RGLB lib1",
        " --RGPL ILLUMINA --RGPU unit1 --RGSM 20;",
        " mv ${SAMPLE_ID}.rg.bam ${SAMPLE_ID}.bam",
      ],
      jobDefinition: new GenomicsJobDefinition(
        this,
        `${picardAddMissingGroups.jobDefinitionName}AddMissingGroups`,
        picardAddMissingGroups
      ).jobDefinition,
      queue: props.batchQueue,
    };

    const step4Task = new GenomicsTask(
      this,
      step4TaskProps.taskName,
      step4TaskProps
    ).task;

    // Set the fifth task to samtools index
    const step5TaskProps = {
      taskName: "SAMTOOLS-INDEX",
      environment: {
        JOB_INPUTS: sfn.JsonPath.stringAt("$.params.samtoolsIndex.input"),
        SAMPLE_ID: sfn.JsonPath.stringAt("$.params.common.sampleId"),
        JOB_OUTPUTS: sfn.JsonPath.stringAt("$.params.samtoolsIndex.output"),
      },
      command: ["samtools index ${SAMPLE_ID}.bam"],
      jobDefinition: new GenomicsJobDefinition(
        this,
        `${samToolsIndex.jobDefinitionName}Index`,
        samToolsIndex
      ).jobDefinition,
      queue: props.batchQueue,
    };

    const step5Task = new GenomicsTask(
      this,
      step5TaskProps.taskName,
      step5TaskProps
    ).task;

    // set the fifth task to gatk HaplotypeCaller
    const step6TaskProps = {
      taskName: "GATK-HAPLOTYPECALLER",
      environment: {
        JOB_INPUTS: sfn.JsonPath.stringAt("$.params.gatk.input"),
        SAMPLE_ID: sfn.JsonPath.stringAt("$.params.common.sampleId"),
        REFERENCE_NAME: sfn.JsonPath.stringAt("$.params.common.referenceName"),
        JOB_OUTPUTS: sfn.JsonPath.stringAt("$.params.gatk.output"),
        JOB_INPUT_S3_COPY_METHOD: "s3sync"
      },
      command: [
        'gatk --java-options "-Xmx4g" HaplotypeCaller',
        ' -R ${REFERENCE_NAME}.fasta -I ${SAMPLE_ID}.bam',
        ' -O ${SAMPLE_ID}.vcf.gz -bamout ${SAMPLE_ID}.out.bam',
      ],
      jobDefinition: new GenomicsJobDefinition(
        this,
        `${gatkHaplotypeCaller.jobDefinitionName}HaplotypeCaller`,
        gatkHaplotypeCaller
      ).jobDefinition,
      queue: props.batchQueue,
    };

    const step6Task = new GenomicsTask(
      this,
      step6TaskProps.taskName,
      step6TaskProps
    ).task;

    const definition = step1Task.next(
      step2Task.next(step3Task.next(step4Task.next(step5Task.next(step6Task))))
    );

    const stateMachineProps = {
      definition,
      stateMachineName: "genomics-pipelines-variant-calling",
      timeout: cdk.Duration.seconds(totalTimeout),
    };

    new sfn.StateMachine(
      this,
      stateMachineProps.stateMachineName,
      stateMachineProps
    );
  }
}
