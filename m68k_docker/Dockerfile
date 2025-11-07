FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    BASE_URL=https://limu.ait.kyushu-u.ac.jp/~minematsu/kisosoft/ \
    SUPP=m68k-6.4.tgz \
    BIN=m68k-elf.tgz \
    PATCH=bsvc-2.4.6.patch.tgz \
    DISPLAY=:0 \
    LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      make gcc g++ tk quilt curl git wget ca-certificates \
      xauth libx11-6 libxext6 libxft2 libxrender1 fonts-ipafont \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp_for_bsvc

RUN wget -q "${BASE_URL}${BIN}" && \
    mkdir -p /usr/local/bin && \
    tar -xzf "/tmp_for_bsvc/${BIN}" -C /usr/local/bin

RUN git clone https://github.com/BSVC/bsvc.git && \
    wget -q "${BASE_URL}${PATCH}" && \
    cd bsvc && \
    tar -xzf "/tmp_for_bsvc/${PATCH}" && \
    quilt push && \
    cd src && \
    make -f Makefile.Linux && \
    make -f Makefile.Linux install

RUN wget -q "${BASE_URL}${SUPP}" && \
    tar -xzf "/tmp_for_bsvc/${SUPP}" && \
    cd m68k-supplements && \
    yes | sh install.sh

RUN rm -rf /tmp_for_bsvc

WORKDIR /work
