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
readonly DB_HOST=$4
readonly DB_PORT=$6
readonly DB_ENGINE=$8
readonly DB_VERSION=${10}
readonly DB_USERNAME=${12}
readonly DB_PASSWORD=${14}
readonly MY_NODE_ID=${16}
readonly PRODUCT_NAME=${18}
readonly PRODUCT_VERSION=${20}
readonly DAS2_HOSTNAME=${22}
readonly AWS_ACCESS_KEY_ID=${24}
readonly AWS_ACCESS_KEY_SECRET=${26}
readonly AWS_SECURITY_GROUP=${28}
readonly AWS_REGION=${30}
readonly WUM_PRODUCT_NAME=${PRODUCT_NAME}-${PRODUCT_VERSION}
readonly WUM_PRODUCT_DIR=/home/${USERNAME}/.wum-wso2/products/${PRODUCT_NAME}/${PRODUCT_VERSION}
readonly INSTALLATION_DIR=/opt/wso2
readonly PRODUCT_HOME="${INSTALLATION_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}"

# databases
readonly WSO2_UM_DB="WSO2_UM_DB"
readonly WSO2_REG_DB="WSO2_REG_DB"
readonly WSO2_ANALYTICS_EVENT_STORE="WSO2_ANALYTICS_EVENT_STORE_DB"
readonly WSO2_ANALYTICS_PROCESSED_DATA_STORE="WSO2_ANALYTICS_PROCESSED_DATA_STORE_DB"
readonly WSO2_AM_STATS_DB="WSO2_AM_STATS_DB"

setup_wum_updated_pack() {

    sudo -u ${USERNAME} /usr/local/wum/bin/wum add ${WUM_PRODUCT_NAME} -y
    sudo -u ${USERNAME} /usr/local/wum/bin/wum update ${WUM_PRODUCT_NAME}

    mkdir -p ${INSTALLATION_DIR}
    chown -R ${USERNAME} ${INSTALLATION_DIR}
    echo ">> Copying WUM updated ${WUM_PRODUCT_NAME} to ${INSTALLATION_DIR}"
    sudo -u ${USERNAME} unzip ${WUM_PRODUCT_DIR}/$(ls -t ${WUM_PRODUCT_DIR} | grep .zip | head -1) -d ${INSTALLATION_DIR}
}

copy_libs() {

    echo ">> Copying $DB_ENGINE jdbc driver "
    cp /tmp/jdbc-connector.jar ${PRODUCT_HOME}/repository/components/lib/
}

copy_config_files() {

    echo ">> Copying configuration files "
    cp -r -v /home/ubuntu/cloudformation-das/product-configs/* ${PRODUCT_HOME}/repository/conf/
    echo ">> Done!"
}

copy_bin_files() {

    echo ">> Copying bin files "
    cp -r -v /home/ubuntu/cloudformation-das/product-bin/* ${PRODUCT_HOME}/bin/
    echo ">> Done!"
}

configure_product() {
    DB_TYPE=$(get_jdbc_url_prefix)
    DRIVER_CLASS=$(get_driver_class)
    DAS_HOST_NAME=$(get_host_ip)

    echo ">> Configuring product "
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" -o -iname "*.sh" \) -print0 | xargs -0 sed -i 's/#_DAS_HOSTNAME_#/'$DAS_HOST_NAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" -o -iname "*.sh" \) -print0 | xargs -0 sed -i 's/#_DAS1_HOSTNAME_#/'$DAS_HOST_NAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" -o -iname "*.sh" \) -print0 | xargs -0 sed -i 's/#_DAS2_HOSTNAME_#/'$DAS2_HOSTNAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_AWS_ACCESS_KEY_ID_#/'$AWS_ACCESS_KEY_ID'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_AWS_ACCESS_KEY_SECRET_#/'$AWS_ACCESS_KEY_SECRET'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_AWS_SECURITY_GROUP_#/'$AWS_SECURITY_GROUP'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_AWS_REGION_#/'$AWS_REGION'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_RDS_HOSTNAME_#/'$DB_HOST'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_RDS_PORT_#/'$DB_PORT'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_RDS_TYPE_#/'$DB_TYPE'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DRIVER_CLASS_#/'$DRIVER_CLASS'/g'
    if [ $DB_ENGINE = "mysql" ]; then
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_UM_DB_#/'\\/$WSO2_UM_DB'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_REG_DB_#/'\\/$WSO2_REG_DB'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_ANALYTICS_PROCESSED_DATA_STORE_DB_#/'\\/$WSO2_ANALYTICS_PROCESSED_DATA_STORE'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_ANALYTICS_EVENT_STORE_DB_#/'\\/$WSO2_ANALYTICS_EVENT_STORE'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_AM_STATS_DB_#/'\\/$WSO2_AM_STATS_DB'/g'
    elif [ $DB_ENGINE = "sqlserver-ex" ]; then
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_UM_DB_#/'\;databaseName=$WSO2_UM_DB'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_REG_DB_#/'\;databaseName=$WSO2_REG_DB'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_ANALYTICS_PROCESSED_DATA_STORE_DB_#/'\;databaseName=$WSO2_ANALYTICS_PROCESSED_DATA_STORE'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_ANALYTICS_EVENT_STORE_DB_#/'\;databaseName=$WSO2_ANALYTICS_EVENT_STORE'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_AM_STATS_DB_#/'\;databaseName=$WSO2_AM_STATS_DB'/g'
    fi
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DB_USER_#/'$DB_USERNAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DB_PWD_#/'$DB_PASSWORD'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.dat" \) -print0 | xargs -0 sed -i 's/#_MY_NODE_ID_#/'$MY_NODE_ID'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.conf" \) -print0 | xargs -0 sed -i 's/#_PRODUCT_HOME_#/'${PRODUCT_NAME}-${PRODUCT_VERSION}'/g'

    echo "Done!"
}

get_host_ip() {
  DAS_HOST_NAME=""
  DAS_HOST_NAME= ifconfig | awk '/inet addr/{split($2,a,":"); print a[2]}' | awk 'NR == 1'
  echo $DAS_HOST_NAME
}

get_driver_class() {
    DRIVER_CLASS=""
    if [ $DB_ENGINE = "postgres" ]; then
        DRIVER_CLASS="org.postgresql.Driver"
    elif [ $DB_ENGINE = "mysql" ]; then
	DRIVER_CLASS="com.mysql.jdbc.Driver"
    elif [ $DB_ENGINE = "oracle-se" ]; then
        DRIVER_CLASS="oracle.jdbc.driver.OracleDriver"
    elif [ $DB_ENGINE = "sqlserver-ex" ]; then
        DRIVER_CLASS="com.microsoft.sqlserver.jdbc.SQLServerDriver"
    elif [ $DB_ENGINE = "mariadb" ]; then
        DRIVER_CLASS="com.mysql.jdbc.Driver"
    fi
    echo $DRIVER_CLASS
}

get_jdbc_url_prefix() {
    URL=""
    if [ $DB_ENGINE = "postgres" ]; then
        URL="postgresql"
    elif [ $DB_ENGINE = "mysql" ]; then
	URL="mysql"
    elif [ $DB_ENGINE = "oracle-se" ]; then
        URL="oracle:thin"
    elif [ $DB_ENGINE = "sqlserver-ex" ]; then
        URL="sqlserver"
    elif [ $DB_ENGINE = "mariadb" ]; then
        URL="mariadb"
    fi
    echo $URL
}

start_product() {
    chown -R ${USERNAME} ${PRODUCT_HOME}
    echo ">> Starting WSO2 DAS Server ... "
    sudo -u ${USERNAME} bash ${PRODUCT_HOME}/bin/wso2server.sh start
}

main() {
    setup_wum_updated_pack
    copy_libs
    copy_bin_files
    copy_config_files
    configure_product
    start_product
}

main
