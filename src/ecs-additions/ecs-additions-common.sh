#!/bin/bash

cd /usr/local/bin && curl --retry 5 --retry-connrefused $artifactRootUrl/fetch_and_run.sh -o "fetch_and_run.sh" && chmod a+x ./fetch_and_run.sh