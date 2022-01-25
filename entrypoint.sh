#!/bin/bash
set -e

PATH=/usr/local/bin:$PATH

case $CLOUD in 
  gcp)
    LOCAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
    PUBLIC_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
    ;;
  aws)
    if [ -z "$IMDSv2" ]; then
      LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
      PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    else 
      LOCAL_IP=$(TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
      PUBLIC_IP=$(TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
    fi
    ;;
  digitalocean)
    LOCAL_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
    PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
    ;;
  azure)
    LOCAL_IP=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-08-01&format=text")
    PUBLIC_IP=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-08-01&format=text")
    ;;
  *)
    ;;
esac

if [ -z "$PUBLIC_IP" ]; then
  LOCAL_IP=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
  PUBLIC_IP=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
fi

if [ -z "$RTP_START_PORT" ]; then
  RTP_START_PORT=40000
fi
if [ -z "$RTP_END_PORT" ]; then
  RTP_END_PORT=60000
fi
if [ -z "$LOGLEVEL" ]; then
  LOGLEVEL=6
fi

if [ "$1" = 'rtpengine' ]; then
  shift
  exec rtpengine \
  --interface private/${LOCAL_IP} --interface public/${LOCAL_IP}!${PUBLIC_IP} \
  --port-min ${RTP_START_PORT} --port-max ${RTP_END_PORT} \
  --log-level ${LOGLEVEL} --port-min ${RTP_START_PORT} --port-max ${RTP_END_PORT} \
  --listen-ng=22222 --listen-http=8080 --listen-udp=12222 \
  --dtmf-log-dest=127.0.0.1:22223 \
  --listen-cli=127.0.0.1:9900 \
  --pidfile /var/run/rtpengine.pid \
  --recording-dir /tmp --recording-method pcap --recording-format eth \
  --delete-delay 0 \
  --log-stderr \
  --foreground \
  $@
else 
  exec "$@"
fi
