FROM openjdk:8-slim

RUN apt update && apt -y install git rsync wget zip libc++-dev squashfs-tools make gcc zlib1g-dev

WORKDIR /
COPY haystack /haystack
COPY simple-deodexer /simple-deodexer
COPY vdexExtractor /vdexExtractor
RUN cd /vdexExtractor && ./make.sh
RUN wget -O/mapsv1.flashable.zip https://github.com/microg/android_frameworks_mapsv1/releases/download/v0.1.0/mapsv1.flashable.zip

ADD *.sh ./
RUN mkdir /sailfish

ENV SAILFISH 192.168.2.15
# DEBUG
# CMD ["bash", "-x", "./run.sh"]
CMD ["bash", "./run.sh"]
