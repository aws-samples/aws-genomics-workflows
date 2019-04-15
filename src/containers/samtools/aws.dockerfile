FROM samtools:latest

RUN apt-get install -y awscli
RUN apt-get clean

ENV PATH=/opt/bin:$PATH

COPY samtools.aws.sh /opt/bin/samtools.aws.sh
RUN chmod +x /opt/bin/samtools.aws.sh

WORKDIR /scratch

ENTRYPOINT ["samtools.aws.sh"]
