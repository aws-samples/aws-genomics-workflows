FROM public.ecr.aws/lts/ubuntu:18.04 AS build

ARG BWA_VERSION=0.7.17

RUN apt-get update -y \
 && apt-get install -y \
    wget \
    make \
    gcc \
    zlib1g-dev \
    bzip2


WORKDIR /opt/src
RUN wget https://github.com/lh3/bwa/releases/download/v${BWA_VERSION}/bwa-${BWA_VERSION}.tar.bz2 \
 && tar -xjvf bwa-*.tar.bz2 \
 && cd bwa-* \
 && make \
 && cp bwa /opt/src


FROM public.ecr.aws/lts/ubuntu:18.04 AS final

RUN apt-get update -y \
 && apt-get install -y \
    wget \
    make \
    zlib1g \
    bzip2 \
 && apt-get clean

WORKDIR /opt/bin
COPY --from=build /opt/src/bwa .

ENV PATH=/opt/bin:$PATH

WORKDIR /scratch

ENTRYPOINT ["bwa"]