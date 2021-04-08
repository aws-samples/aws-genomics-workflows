#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "@aws-cdk/core";
import { AwsGenomicsCdkStack } from "../lib/aws-genomics-cdk-stack";
import * as config from "../app.config.json";

const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT ?? config.accountID,
  region: process.env.CDK_DEFAULT_REGION ?? config.region,
};

const app = new cdk.App();
const genomicsStack = new AwsGenomicsCdkStack(
  app,
  `${config.projectName}CdkStack`,
  {
    env: env,
  }
);

for (let i = 0; i < config.tags.length; i++) {
  cdk.Tags.of(genomicsStack).add(config.tags[i].name, config.tags[i].value);
}
