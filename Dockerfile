FROM debian:jessie

WORKDIR /root

RUN apt-get update \
    && apt-get install -y wget python xz-utils cron git \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-176.0.0-linux-x86_64.tar.gz \
    && tar -zxf google-cloud-sdk-176.0.0-linux-x86_64.tar.gz \
    && ./google-cloud-sdk/install.sh --usage-reporting false \
    && rm google-cloud-sdk-176.0.0-linux-x86_64.tar.gz

COPY lego_v4.6.0_linux_amd64.tar.gz lego.tar.gz
RUN tar -xzf lego.tar.gz lego \
    && mv ./lego /usr/bin/ \
    && rm lego.tar.gz

COPY start.sh /root/start.sh
COPY init.sh /root/init.sh
COPY monthly.sh /root/monthly.sh

COPY crontab /etc/cron.d/letsencrypt

CMD /root/start.sh
