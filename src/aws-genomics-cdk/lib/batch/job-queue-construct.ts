import * as cdk from "@aws-cdk/core";
import * as batch from "@aws-cdk/aws-batch";

export interface GenomicsJobQueueProps {
  readonly computeEnvironments: batch.ComputeEnvironment[];
  readonly jobQueueName: string;
  readonly priority: number;
}

export default class GenomicsJobQueue extends cdk.Construct {
  public readonly jobQueue: batch.JobQueue;

  constructor(scope: cdk.Construct, id: string, props: GenomicsJobQueueProps) {
    super(scope, id);

    let environments = [];
    for (let i = 0; i < props.computeEnvironments.length; i++) {
      let environment = {
        computeEnvironment: props.computeEnvironments[i],
        order: i + 1,
      };

      environments.push(environment);
    }

    let jobQueueProps = {
      jobQueueName: props.jobQueueName,
      priority: props.priority,
      computeEnvironments: environments,
    };

    this.jobQueue = new batch.JobQueue(
      this,
      jobQueueProps.jobQueueName,
      jobQueueProps
    );
  }
}
