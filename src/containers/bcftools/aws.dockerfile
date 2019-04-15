FROM bcftools:latest

RUN apt-get install -y awscli
RUN apt-get clean

ENV PATH=/opt/bin:$PATH

COPY bcftools.aws.sh /opt/bin/bcftools.aws.sh
RUN chmod +x /opt/bin/bcftools.aws.sh

WORKDIR /scratch

ENTRYPOINT ["bcftools.aws.sh"]
