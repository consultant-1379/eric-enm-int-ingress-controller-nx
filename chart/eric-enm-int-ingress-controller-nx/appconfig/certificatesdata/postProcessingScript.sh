#!/bin/bash

CREDM_DATA_XML="ingress-nginx-cert-request.xml"
SECRET_NAME="ingress-nginx-secret"

# for TORF-659964
KEY_LOCATION="/ericsson/ingress/ingress-nginx-enm_ingress.key"
CRT_LOCATION="/ericsson/ingress/ingress-nginx-enm_ingress.crt"

SECRET_1_NAME="ingress-nginx-tls-secret-1"
SECRET_2_NAME="ingress-nginx-tls-secret-2"

TLS_KEY=""
TLS_CRT=""

# read secret1
SECRET1_LOCATION=$(kubectl get secrets/$SECRET_1_NAME --template={{.data.tlsStoreLocation}} -n $NAMESPACE | base64 -d)
if [[ "$SECRET1_LOCATION" == "$KEY_LOCATION" ]]; then
	TLS_KEY=$(kubectl get secret ${SECRET_1_NAME} -n ${NAMESPACE} -ojsonpath='{.data.tlsStoreData}')
fi
if [[ "$SECRET1_LOCATION" == "$CRT_LOCATION" ]]; then
	TLS_CRT=$(kubectl get secret ${SECRET_1_NAME} -n ${NAMESPACE} -ojsonpath='{.data.tlsStoreData}')
fi

# read secret2
SECRET2_LOCATION=$(kubectl get secrets/$SECRET_2_NAME --template={{.data.tlsStoreLocation}} -n $NAMESPACE | base64 -d)
if [[ "$SECRET2_LOCATION" == "$KEY_LOCATION" ]]; then
	TLS_KEY=$(kubectl get secret ${SECRET_2_NAME} -n ${NAMESPACE} -ojsonpath='{.data.tlsStoreData}')

fi
if [[ "$SECRET2_LOCATION" == "$CRT_LOCATION" ]]; then
	TLS_CRT=$(kubectl get secret ${SECRET_2_NAME} -n ${NAMESPACE} -ojsonpath='{.data.tlsStoreData}')
fi


echo "EXECUTION POST_CREDM SCRIPT for ${CREDM_DATA_XML}"
now=$(date +"%T")
echo "Current time : $now"
echo "-------------------"

echo "EXECUTION SCRIPTS IN POST_CREDM for ${CREDM_DATA_XML} at $now"

# check if ingress tls secret already exists
secret_exists=$(kubectl get secret -n ${NAMESPACE} | grep ${SECRET_NAME} | wc -l)

# if no secrets exist
if [[ $secret_exists == 0 ]]; then
    echo "Secret doesn't exist: creating ingress-nginx-secret"
    echo $TLS_KEY | base64 -d > /tmp/key.pem
    echo $TLS_CRT | base64 -d > /tmp/crt.pem
    kubectl create secret tls ${SECRET_NAME} -n ${NAMESPACE} --cert=/tmp/crt.pem --key=/tmp/key.pem
    rm /tmp/key.pem
    rm /tmp/crt.pem
    kubectl get secret -n ${NAMESPACE} ${SECRET_NAME} &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "error creating ${SECRET_NAME}, exiting..."
        exit 1
    fi
    kubectl rollout restart deployment eric-oss-ingress-controller-nx -n ${NAMESPACE} 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "error restarting eric-oss-ingress-controller-nx, exiting..."
        exit 1
    fi
else
    # check if key or cert have been updated and update existing tls secret's data
    current_tls_key=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -ojsonpath='{.data.tls\.key}')
    current_tls_cert=$(kubectl get secret ${SECRET_NAME} -n ${NAMESPACE} -ojsonpath='{.data.tls\.crt}')
    current_tls_data="${current_tls_key}${current_tls_cert}"
    if [[ $current_tls_data != "${TLS_KEY}${TLS_CRT}" ]]; then
        kubectl patch secret ${SECRET_NAME} -n ${NAMESPACE} -p="{\"data\":{\"tls.crt\":\"${TLS_CRT}\",\"tls.key\":\"${TLS_KEY}\"}}" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "error patching ${SECRET_NAME}, exiting..."
            exit 1
        fi
        kubectl rollout restart deployment eric-oss-ingress-controller-nx -n ${NAMESPACE} 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "error restarting eric-oss-ingress-controller-nx, exiting..."
            exit 1
        fi
    fi
fi

exit 0
