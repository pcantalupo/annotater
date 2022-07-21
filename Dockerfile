FROM ubuntu:20.04
MAINTAINER Paul Cantalupo <pcantalupo@gmail.com>
RUN apt-get update && apt-get install --yes \
 build-essential \
 apt-utils \
 wget \
 git \
 cpanminus \
 perl-doc

WORKDIR /opt

RUN git clone https://github.com/pcantalupo/annotater
ENV PATH "$PATH:/opt/annotater:/opt/annotater/bin"
ENV PERL5LIB "$PERL5LIB:/opt/annotater"

# get bioperl repos
RUN git clone https://github.com/bioperl/bioperl-live
RUN git clone https://github.com/bioperl/Bio-EUtilities
ENV PERL5LIB "$PERL5LIB:/opt/bioperl-live/lib:/opt/Bio-EUtilities/lib"

#RUN cpanm Bio::LITE::Taxonomy \
# Bio::LITE::Taxonomy::NCBI \
# Bio::LITE::Taxonomy::NCBI::Gi2taxid

RUN cpanm LWP::UserAgent

# https://github.com/sjackman/docker-bio/issues/2#issuecomment-257991372
RUN apt-get install --yes libxml-sax-expat-incremental-perl
RUN cpanm XML::Simple

# ftp does not work so using https
RUN wget -v https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.13.0+-x64-linux.tar.gz
RUN tar xvzf ncbi-blast-2.13.0+-x64-linux.tar.gz
RUN rm ncbi-blast-2.13.0+-x64-linux.tar.gz
ENV PATH "$PATH:/opt/ncbi-blast-2.13.0+/bin"

WORKDIR /opt/annotater
RUN perl Makefile.PL
RUN make
RUN make test
#RUN prove -v t/Reann.t

WORKDIR /tmp
CMD ["/bin/bash"]

