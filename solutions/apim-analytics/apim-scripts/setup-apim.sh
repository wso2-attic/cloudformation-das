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
readonly PRODUCT_NAME=${16}
readonly PRODUCT_VERSION=${18}
readonly DAS1_IP=${20}
readonly DAS2_IP=${22}

readonly WUM_PRODUCT_NAME=${PRODUCT_NAME}-${PRODUCT_VERSION}
readonly WUM_PRODUCT_DIR=/home/${USERNAME}/.wum-wso2/products/${PRODUCT_NAME}/${PRODUCT_VERSION}
readonly INSTALLATION_DIR=/opt/wso2
readonly PRODUCT_HOME="${INSTALLATION_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}"
readonly DB_SCRIPTS_PATH="${PRODUCT_HOME}/dbscripts/apimgt"

# databases
readonly WSO2_AM_DB="WSO2_AM_DB"
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
    cp /tmp/jdbc-connector.jar ${PRODUCT_HOME}/repository/components/lib
}

copy_config_files() {

    echo ">> Copying configuration files "
    cp -r -v /home/ubuntu/cloudformation-das/solutions/apim-analytics/product-apim-config/* ${PRODUCT_HOME}/repository/conf/
    echo ">> Done!"
}

copy_bin_files() {

    echo ">> Copying bin files "
    cp -r -v /home/ubuntu/cloudformation-das/solutions/apim-analytics/product-bin/* ${PRODUCT_HOME}/bin/
    echo ">> Done!"
}

configure_product() {
    DB_TYPE=$(get_jdbc_url_prefix)
    DRIVER_CLASS=$(get_driver_class)
    DAS_HOST_NAME=$(get_host_ip)

    echo ">> Configuring product "
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DAS1_IP_#/'$DAS1_IP'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DAS2_IP_#/'$DAS2_IP'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_RDS_HOSTNAME_#/'$DB_HOST'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_RDS_PORT_#/'$DB_PORT'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_RDS_TYPE_#/'$DB_TYPE'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DRIVER_CLASS_#/'$DRIVER_CLASS'/g'
    if [ $DB_ENGINE = "mysql" ]; then
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_AM_DB_#/'\\/$WSO2_AM_DB'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_AM_STATS_DB_#/'\\/$WSO2_AM_STATS_DB'/g'
    elif [ $DB_ENGINE = "sqlserver-ex" ]; then
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_AM_DB_#/'\;databaseName=$WSO2_AM_DB'/g'
      find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_WSO2_AM_STATS_DB_#/'\;databaseName=$WSO2_AM_STATS_DB'/g'
    fi
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DB_USER_#/'$DB_USERNAME'/g'
    find ${PRODUCT_HOME}/ -type f \( -iname "*.properties" -o -iname "*.xml" \) -print0 | xargs -0 sed -i 's/#_DB_PWD_#/'$DB_PASSWORD'/g'
    echo "Done!"
}

init_mysql_rds() {

    echo ">> Setting up MySQL databases ..."
    echo ">> Creating databases..."
    mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD \
    -e "DROP DATABASE IF EXISTS $WSO2_AM_DB;
    CREATE DATABASE $WSO2_AM_DB;"

    echo ">> Databases created!"

    echo ">> Creating tables..."
    if [[ $DB_VERSION == "5.7*" ]]; then
        mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD \
        -e "USE $WSO2_AM_DB;
        GRANT ALL PRIVILEGES ON $WSO2_AM_DB.* TO '$DB_USERNAME'@'%';
        SOURCE $DB_SCRIPTS_PATH/mysql5.7.sql;"
    else
        mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD \
        -e "USE $WSO2_AM_DB;
        GRANT ALL PRIVILEGES ON $WSO2_AM_DB.* TO '$DB_USERNAME'@'%';
        SOURCE $DB_SCRIPTS_PATH/mysql.sql;"
    fi
    echo ">> Tables created!"
}

init_sqlserver_rds() {
    echo ">> Setting up SQLServer databases ..."
    echo ">> Creating databases..."
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $WSO2_AM_DB"
    echo ">> Databases created!"

    echo ">> Creating tables..."
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $WSO2_AM_DB -i $DB_SCRIPTS_PATH/mssql.sql
    echo ">> Tables created!"
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
    echo ">> Starting WSO2 APIM Server ... "
    sudo -u ${USERNAME} bash ${PRODUCT_HOME}/bin/wso2server.sh start
}

main() {
    setup_wum_updated_pack
    if [ $DB_ENGINE = "mysql" ]; then
    init_mysql_rds
    elif [ $DB_ENGINE = "sqlserver-ex" ]; then
    init_sqlserver_rds
    fi
    copy_libs
    copy_bin_files
    copy_config_files
    configure_product
    start_product
}

main
