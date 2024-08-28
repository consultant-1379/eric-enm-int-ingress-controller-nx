#!/bin/bash
#----------------------------------------------------------------------------
#############################################################################
# COPYRIGHT Ericsson 2022
# The copyright to the computer program herein is the property of
# conditions stipulated in the agreement/contract under which the
# program have been supplied.
#############################################################################
#----------------------------------------------------------------------------

# Pre-processing script
readonly CREDM_DATA_XML_FILENAME="ingress-nginx-cert-request.xml"
readonly CREDM_DATA_DIR="/ericsson/credm/data/xmlfiles"
readonly GLOBAL_PROPERTIES="/ericsson/tor/data/global.properties"
readonly CREDM_DATA_XML="${CREDM_DATA_DIR}/${CREDM_DATA_XML_FILENAME}"
readonly TEMP_DIR="/tmp"
readonly TEMP_CREDM_DATA_XML="${TEMP_DIR}/${CREDM_DATA_XML_FILENAME}"
readonly CERT_REQUEST_SECRET="ingress-nginx-certreq-secret-1"
UI_PRES_SERVER_VALUE=""

echo "EXECUTION PRE-START SCRIPT for ingress-nginx-cert-request.xml"
now=$(date +"%T")
echo "Current time : $now"
echo "-------------------"

echo "EXECUTION SCRIPTS IN PRE_START for ${CREDM_DATA_XML_FILENAME} at $now"

# READ FROM GLOBAL PROPERTIES
echo "check global.properties"
if [ -f "$GLOBAL_PROPERTIES" ]; then
    UI_PRES_SERVER_VALUE=$(grep UI_PRES_SERVER $GLOBAL_PROPERTIES | cut -d '=' -f 2-)
    echo "UI_PRES_SERVER value from $GLOBAL_PROPERTIES : $UI_PRES_SERVER_VALUE"
    if [ -z "$UI_PRES_SERVER_VALUE" ]; then
        echo "UI_PRES_SERVER not found in $GLOBAL_PROPERTIES"
        exit 1
    fi

    INGRESS_LOADBALANCER_IPV4=$(grep ingressControllerLoadBalancerIP= $GLOBAL_PROPERTIES | cut -d '=' -f 2-)
    INGRESS_LOADBALANCER_IPV6=$(grep ingressControllerLoadBalancerIP_IPv6 $GLOBAL_PROPERTIES | cut -d '=' -f 2-)

    if [ -z "$INGRESS_LOADBALANCER_IPV4" ] && [ -z "$INGRESS_LOADBALANCER_IPV6" ]; then
        echo "ingressControllerLoadBalancerIP and ingressControllerLoadBalancerIP_IPv6 not found in $GLOBAL_PROPERTIES"
        exit 1
    fi

    echo "Ingress_loadBalancerIP value from $GLOBAL_PROPERTIES : $INGRESS_LOADBALANCER_IPV4"
    echo "Ingress_loadBalancerIP_IPv6 value from $GLOBAL_PROPERTIES : $INGRESS_LOADBALANCER_IPV6"

else
    echo "$GLOBAL_PROPERTIES NOT FOUND"
    exit 1
fi

# CHECK THE PRESENCE of XML FILE AND UPDATE IT
echo "check and update ${CREDM_DATA_XML_FILENAME}"
if [ -f "$CREDM_DATA_XML" ]; then
    echo "Updating $CREDM_DATA_XML"
    cp ${CREDM_DATA_XML} ${TEMP_CREDM_DATA_XML}
    cat ${TEMP_CREDM_DATA_XML} | sed -e "s/##UI_PRES_SERVER##/${UI_PRES_SERVER_VALUE}/" >${CREDM_DATA_XML} 2>/dev/null
    UI_PRES_RES=$?


    # Update IPV4 value in XML or remove line from XML
    cp ${CREDM_DATA_XML} ${TEMP_CREDM_DATA_XML}
    if [ -z "$INGRESS_LOADBALANCER_IPV4" ]; then
        # Remove IPV4 line from XML as IP not present
        cat ${TEMP_CREDM_DATA_XML} | sed -e "/##LOADBALANCER_IPv4##/d" >${CREDM_DATA_XML} 2>/dev/null
        INGRESS_IPV4_RES=$?
    else
        cat ${TEMP_CREDM_DATA_XML} | sed -e "s/##LOADBALANCER_IPv4##/${INGRESS_LOADBALANCER_IPV4}/" >${CREDM_DATA_XML} 2>/dev/null
        INGRESS_IPV4_RES=$?
    fi

    # Update IPV6 Value in XML or remove line from XML
    cp ${CREDM_DATA_XML} ${TEMP_CREDM_DATA_XML}
    if [ -z "$INGRESS_LOADBALANCER_IPV6" ]; then
        # Remove IPV6 line from XML as IP not present
        cat ${TEMP_CREDM_DATA_XML} | sed -e "/##LOADBALANCER_IPv6##/d" >${CREDM_DATA_XML} 2>/dev/null
        INGRESS_IPV6_RES=$?
    else
        cat ${TEMP_CREDM_DATA_XML} | sed -e "s/##LOADBALANCER_IPv6##/${INGRESS_LOADBALANCER_IPV6}/" >${CREDM_DATA_XML} 2>/dev/null
        INGRESS_IPV6_RES=$?
    fi

    if [ $UI_PRES_RES -eq 0 ] && [ $INGRESS_IPV4_RES -eq 0 ] && [ $INGRESS_IPV6_RES -eq 0 ]; then
        echo "$CREDM_DATA_XML file updated successfully"
    else
        echo "$CREDM_DATA_XML file update FAILED"
        rm ${TEMP_CREDM_DATA_XML}
        exit 1
    fi
    rm ${TEMP_CREDM_DATA_XML}
else
    echo "$CREDM_DATA_XML NOT FOUND"
    exit 1
fi

echo "END PRE-START SCRIPT for ${CREDM_DATA_XML_FILENAME} ingress"
exit 0
