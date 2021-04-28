FROM ubuntu:18.04 AS build

ARG VERSION=2.17

# metadata
LABEL base.image="ubuntu:18.04"
LABEL container.version="1"
LABEL software="Minimap2"
LABEL software.version="${VERSION}"
LABEL description="versatile sequence alignment program that aligns DNA or mRNA sequences against a large reference database"
LABEL website="https://github.com/lh3/minimap2"
LABEL license="https://github.com/lh3/minimap2/blob/master/LICENSE.txt"
LABEL maintainer="Kelsey Florek"
LABEL maintainer.email="Kelsey.florek@slh.wisc.edu"

# install dependeny tools
RUN apt-get update && apt-get install -y python curl bzip2 && apt-get clean

# download and extract minimap2
WORKDIR /opt/bin
RUN curl -L https://github.com/lh3/minimap2/releases/download/v2.17/minimap2-2.17_x64-linux.tar.bz2 | tar -jxvf -

# add minimap2 to the path
ENV PATH="${PATH}:/opt/bin/minimap2-2.17_x64-linux"

WORKDIR /scratch

ENTRYPOINT ["minimap2"]