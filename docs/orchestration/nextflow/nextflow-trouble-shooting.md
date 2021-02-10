# Nextflow Troubleshooting

The following are some common errors that we have seen and suggested solutions

## Job Logs say there is an error in AWS CLI while loading shared libraries
### Possible Cause(s)
Nextflow on AWS Batch relies on the process containers being able to use the AWS CLI (which is mounted from the container host).
Very minimal container images such as Alpine do not contain the `glibc` libraries needed by the AWS CLI.

### Suggested Solution(s)

 * Modify your image to include or mount these dependencies
 * Use an image (or build from a base) that already contains these such as `ubuntu:latest`