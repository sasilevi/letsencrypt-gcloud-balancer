#!/bin/bash

set -e

SERVICE_ACCOUNT_FILE=/root/service_account/service-account.json

check_file_exist(){
    if test -f "$1"; then
        echo "$1 exists."
    else
        echo "service account file is missing"
        exit 1
    fi
}

# Validate all requierments for run are met!
: ${OPERATION?"Need to set OPERATION"}
: ${GCS_BUCKET?"Need to set GCS_BUCKET"}
: ${GCE_PROJECT?"Need to set GCE_PROJECT"}
: ${LETSENCRYPT_EMAIL?"Need to set LETSENCRYPT_EMAIL"}
: ${DOMAINS_LIST?"Need to set DOMAINS_LIST"}
: ${SERVICE_ACCOUNT_FILE?"Need to set SERVICE_ACCOUNT_FILE"}

PROJECT_ID=$GCE_PROJECT
BACKUP_PATH=gs://$GCS_BUCKET/certificates/$PROJECT_ID
check_file_exist $SERVICE_ACCOUNT_FILE
export GCE_SERVICE_ACCOUNT_FILE=$SERVICE_ACCOUNT_FILE


# Set Staging server if parameter is set
USE_STAGING_SERVER="${USE_STAGING_SERVER+--server=https://acme-staging-v02.api.letsencrypt.org/directory}"

# gcloud auth with service account
export GOOGLE_APPLICATION_CREDENTIALS=$SERVICE_ACCOUNT_FILE
gcloud auth activate-service-account --key-file $SERVICE_ACCOUNT_FILE

echo "You have selected $OPERATION operation"

if [ "$OPERATION" = "create" ]
then
    echo "run create certificate."
    lego $USE_STAGING_SERVER --dns-timeout 30 -k rsa2048 -m $LETSENCRYPT_EMAIL -dns gcloud $DOMAINS_LIST -a run
elif [ "$OPERATION" = "renew" ]
then
    echo "run update certificate."
    #TODO: get old certificate from bucket decide on folder naming convension
    gsutil cp $BACKUP_PATH/* .
    lego $USE_STAGING_SERVER --dns-timeout 30 -k rsa2048 -m $LETSENCRYPT_EMAIL -dns gcloud $DOMAINS_LIST -a renew
else
    echo "not supported operation $OPERATION, plase use create/renew"
    exit 1
fi

# Create certificate chain
CERT=$(ls -1 /root/.lego/certificates | grep crt\$ | grep -m1 -v issuer)
CERT_ISSUER=$(ls -1 /root/.lego/certificates | grep crt\$ | grep -m1 issuer)
KEY=$(ls -1 /root/.lego/certificates | grep key\$)
cat /root/.lego/certificates/$CERT /root/.lego/certificates/$CERT_ISSUER > cert.crt

# Create name for new certificate in gcloud
CERT_ID=${CERT_ID_PREFIX}cert-$(cat /dev/urandom | tr -dc 'a-z' | fold -w 16 | head -n 1)
OLD_CERT_ID=$(gcloud -q compute target-https-proxies list --filter "name=${TARGET_PROXY}" | sed -n 2p | awk '{print $2}')

# Generate new gcloud certificate and attach to https proxy
gcloud -q compute ssl-certificates create $CERT_ID --certificate=cert.crt --private-key=/root/.lego/certificates/$KEY
gcloud -q compute target-https-proxies update $TARGET_PROXY --ssl-certificates $CERT_ID
rm cert.crt

# Remove old, unused certificate
gcloud -q compute ssl-certificates delete $OLD_CERT_ID

#TODO: upload created certificate to bucket
gsutil cp cert.crt $BACKUP_PATH/cert.crt
gsutil cp /root/.lego/certificates/$KEY $BACKUP_PATH/$KEY