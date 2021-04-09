import * as cdk from "@aws-cdk/core";
import * as iam from "@aws-cdk/aws-iam";

export enum GenomicsJobDefinitionTypes {
    FASTQC = "fastqc",
    MINIMAP2 = "minimap2",
    GATK = "gatk",
    BWA = "bwa",
    SAMTOOLS = "samtools",
    PICARD = "picard"
}

export interface GenomicsJobDefinitionProps {
  readonly repository: string;
  readonly jobDefinitionName?: string;
  readonly retryAttempts?: number;
  readonly timeout?: number;
  readonly env: cdk.ResourceEnvironment;
  readonly stack: cdk.Stack;
  readonly jobRole: iam.Role;
  readonly memoryLimit?: number;
  readonly vcpus?: number;
}

export class JobDefinitionBase implements GenomicsJobDefinitionProps {
  public repository: string;
  public jobDefinitionName: string;
  public retryAttempts?: number;
  public timeout?: number;
  public env: cdk.ResourceEnvironment;
  public stack: cdk.Stack;
  public jobRole: iam.Role;
  public memoryLimit?: number;
  public vcpus?: number;

  constructor() {
    this.retryAttempts = 1;
    this.timeout = 3600;
    this.memoryLimit = 16000;
    this.vcpus = 8;
  }
}

export class FastQcJobDefinition extends JobDefinitionBase {
  constructor(props: GenomicsJobDefinitionProps) {
    super();
    this.repository = props.repository;
    this.jobDefinitionName = GenomicsJobDefinitionTypes.FASTQC;
    this.retryAttempts = props.retryAttempts ?? this.retryAttempts;
    this.timeout = props.timeout ?? this.timeout;
    this.env = props.env;
    this.stack = props.stack;
    this.jobRole = props.jobRole;
    this.memoryLimit = props.memoryLimit ?? this.memoryLimit;
    this.vcpus = props.vcpus ?? this.vcpus;
  }
}

export class Minimap2JObDefinition extends JobDefinitionBase {
  constructor(props: GenomicsJobDefinitionProps) {
    super();
    this.repository = props.repository;
    this.jobDefinitionName = GenomicsJobDefinitionTypes.MINIMAP2;
    this.retryAttempts = props.retryAttempts ?? this.retryAttempts;
    this.timeout = props.timeout ?? this.timeout;
    this.env = props.env;
    this.stack = props.stack;
    this.jobRole = props.jobRole;
    this.memoryLimit = props.memoryLimit ?? this.memoryLimit;
    this.vcpus = props.vcpus ?? this.vcpus;
  }
}

export class GatkJObDefinition extends JobDefinitionBase {
  constructor(props: GenomicsJobDefinitionProps) {
    super();
    this.repository = props.repository;
    this.jobDefinitionName = GenomicsJobDefinitionTypes.GATK;
    this.retryAttempts = props.retryAttempts ?? this.retryAttempts;
    this.timeout = props.timeout ?? this.timeout;
    this.env = props.env;
    this.stack = props.stack;
    this.jobRole = props.jobRole;
    this.memoryLimit = props.memoryLimit ?? this.memoryLimit;
    this.vcpus = props.vcpus ?? this.vcpus;
  }
}

export class BwaJObDefinition extends JobDefinitionBase {
  constructor(props: GenomicsJobDefinitionProps) {
    super();
    this.repository = props.repository;
    this.jobDefinitionName = GenomicsJobDefinitionTypes.BWA;
    this.retryAttempts = props.retryAttempts ?? this.retryAttempts;
    this.timeout = props.timeout ?? this.timeout;
    this.env = props.env;
    this.stack = props.stack;
    this.jobRole = props.jobRole;
    this.memoryLimit = props.memoryLimit ?? this.memoryLimit;
    this.vcpus = props.vcpus ?? this.vcpus;
  }
}

export class SamToolsJObDefinition extends JobDefinitionBase {
  constructor(props: GenomicsJobDefinitionProps) {
    super();
    this.repository = props.repository;
    this.jobDefinitionName = GenomicsJobDefinitionTypes.SAMTOOLS;
    this.retryAttempts = props.retryAttempts ?? this.retryAttempts;
    this.timeout = props.timeout ?? this.timeout;
    this.env = props.env;
    this.stack = props.stack;
    this.jobRole = props.jobRole;
    this.memoryLimit = props.memoryLimit ?? this.memoryLimit;
    this.vcpus = props.vcpus ?? this.vcpus;
  }
}

export class PicardJObDefinition extends JobDefinitionBase {
  constructor(props: GenomicsJobDefinitionProps) {
    super();
    this.repository = props.repository;
    this.jobDefinitionName = GenomicsJobDefinitionTypes.PICARD;
    this.retryAttempts = props.retryAttempts ?? this.retryAttempts;
    this.timeout = props.timeout ?? this.timeout;
    this.env = props.env;
    this.stack = props.stack;
    this.jobRole = props.jobRole;
    this.memoryLimit = props.memoryLimit ?? this.memoryLimit;
    this.vcpus = props.vcpus ?? this.vcpus;
  }
}