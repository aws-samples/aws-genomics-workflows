FROM bcftools:latest

RUN apt-get update
RUN apt-get clean

ENV PATH=/opt/bin:$PATH

COPY ../_common/entrypoint.aws.sh /opt/bin/entrypoint.aws.sh
RUN chmod +x /opt/bin/entrypoint.aws.sh

WORKDIR /scratch

ENTRYPOINT ["entrypoint.aws.sh"]
