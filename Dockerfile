FROM ubuntu:eoan
MAINTAINER ch-docker@bobobeach.com

ENV DEBIAN_FRONTEND=noninteractive

# install apache and davical
RUN apt-get update && \
    apt-get install -y tzdata && \
    apt-get install -y \
    --no-install-recommends \
    --no-install-suggests \
    -y \
    apache2 \
    libapache2-mod-php \
    davical \
    && rm -rf /var/lib/apt/lists/*

# setup davical

COPY etc/davical/administration.yml /etc/davical/

COPY 000-davical.conf /etc/apache2/sites-available/
RUN a2ensite 000-davical.conf
RUN a2dissite 000-default
RUN a2enmod php7.3

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 755 /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "davical" ]
