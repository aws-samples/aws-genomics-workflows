ARG BASE_IMAGE
FROM ${BASE_IMAGE}:latest

RUN apt-get update
RUN apt-get install -y gettext-base wget
RUN apt-get clean

ENV PATH=/opt/bin:$PATH

COPY entrypoint.sh /opt/bin/entrypoint.sh
RUN chmod +x /opt/bin/entrypoint.sh

WORKDIR /scratch

ENTRYPOINT ["entrypoint.sh"]