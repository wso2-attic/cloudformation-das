#!/usr/bin/env bash
# ----------------------------------------------------------------------------
#
# Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ----------------------------------------------------------------------------

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# Echoes all commands before executing.
set -o verbose

readonly USERNAME=$2
readonly PRODUCT_NAME=$4
readonly PRODUCT_VERSION=$6
readonly DAS1_HOSTNAME=$8
readonly DAS2_HOSTNAME=${10}

readonly WUM_PRODUCT_NAME=${PRODUCT_NAME}-${PRODUCT_VERSION}
readonly WUM_PRODUCT_DIR=/home/${USERNAME}/.wum-wso2/products/${PRODUCT_NAME}/${PRODUCT_VERSION}
readonly INSTALLATION_DIR=/opt/wso2
readonly PRODUCT_HOME="${INSTALLATION_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}"

setup_wum_updated_pack() {

    sudo -u ${USERNAME} /usr/local/wum/bin/wum add ${WUM_PRODUCT_NAME} -y
    sudo -u ${USERNAME} /usr/local/wum/bin/wum update ${WUM_PRODUCT_NAME}

    mkdir -p ${INSTALLATION_DIR}
    chown -R ${USERNAME} ${INSTALLATION_DIR}
    echo ">> Copying WUM updated ${WUM_PRODUCT_NAME} to ${INSTALLATION_DIR}"
    sudo -u ${USERNAME} unzip ${WUM_PRODUCT_DIR}/$(ls -t ${WUM_PRODUCT_DIR} | grep .zip | head -1) -d ${INSTALLATION_DIR}
}

copy_config_files() {

    echo ">> Copying configuration files "
    cp -r -v /home/ubuntu/cloudformation-das/product-configs/axis2/axis2.xml ${PRODUCT_HOME}/repository/conf/axis2/
    cp -r -v /home/ubuntu/cloudformation-das/product-configs/carbon.xml ${PRODUCT_HOME}/repository/conf/
    cp -r -v /home/ubuntu/cloudformation-das/product-configs/hazlecast.properties ${PRODUCT_HOME}/repository/conf/
    echo ">> Done!"
}

configure_product() {
    DAS_HOST_NAME=$(get_host_ip)

    echo ">> Configuring product "
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" -o -iname "*.sh" \) -print0 | xargs -0 sed -i 's/#_DAS_HOSTNAME_#/'$DAS_HOST_NAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" -o -iname "*.sh" \) -print0 | xargs -0 sed -i 's/#_DAS1_HOSTNAME_#/'$DAS1_HOSTNAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" -o -iname "*.sh" \) -print0 | xargs -0 sed -i 's/#_DAS2_HOSTNAME_#/'$DAS2_HOSTNAME'/g'
    echo "Done!"
}

get_host_ip() {
  DAS_HOST_NAME=""
  DAS_HOST_NAME= ifconfig | awk '/inet addr/{split($2,a,":"); print a[2]}' | awk 'NR == 1'
  echo $DAS_HOST_NAME
}

start_product() {
    chown -R ${USERNAME} ${PRODUCT_HOME}
    echo ">> Starting WSO2 Dummy DAS Server ... "
    sudo -u ${USERNAME} bash ${PRODUCT_HOME}/bin/wso2server.sh -DdisableAnalyticsEngine=true -DdisableAnalyticsExecution=true -DdisableIndexing=true -DdisableDataPurging=true -DdisableAnalyticsSparkCtx=true -DdisableAnalyticsStats=true -DdisableMl=true  -DdisableEventSink=true start
}

main() {
    setup_wum_updated_pack
    copy_config_files
    configure_product
    start_product
}

main
