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
readonly WUM_PRODUCT_NAME=${PRODUCT_NAME}-${PRODUCT_VERSION}
readonly WUM_PRODUCT_DIR=/home/${USERNAME}/.wum-wso2/products/${PRODUCT_NAME}/${PRODUCT_VERSION}
readonly INSTALLATION_DIR=/opt/wso2
readonly PRODUCT_HOME="${INSTALLATION_DIR}/${PRODUCT_NAME}-${PRODUCT_VERSION}"
readonly DB_SCRIPTS_PATH="${PRODUCT_HOME}/dbscripts"

# databases
readonly WSO2_UM_DB="WSO2_UM_DB"
readonly WSO2_REG_DB="WSO2_REG_DB"
readonly WSO2_ANALYTICS_EVENT_STORE="WSO2_ANALYTICS_EVENT_STORE_DB"
readonly WSO2_ANALYTICS_PROCESSED_DATA_STORE="WSO2_ANALYTICS_PROCESSED_DATA_STORE_DB"
readonly WSO2_AM_STATS_DB="WSO2_AM_STATS_DB"

init_mysql_rds() {

    echo ">> Setting up MySQL databases ..."
    echo ">> Creating databases..."
    mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD \
    -e "DROP DATABASE IF EXISTS $WSO2_UM_DB;
    DROP DATABASE IF EXISTS $WSO2_REG_DB;
    DROP DATABASE IF EXISTS $WSO2_ANALYTICS_EVENT_STORE;
    DROP DATABASE IF EXISTS $WSO2_ANALYTICS_PROCESSED_DATA_STORE;
    DROP DATABASE IF EXISTS $WSO2_AM_STATS_DB;
    CREATE DATABASE $WSO2_UM_DB;
    CREATE DATABASE $WSO2_REG_DB;
    CREATE DATABASE $WSO2_ANALYTICS_EVENT_STORE;
    CREATE DATABASE $WSO2_ANALYTICS_PROCESSED_DATA_STORE;
    CREATE DATABASE $WSO2_AM_STATS_DB;"
    echo ">> Databases created!"

    echo ">> Creating tables..."
    if [[ $DB_VERSION == "5.7*" ]]; then
        mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD \
        -e "USE $WSO2_UM_DB;
        GRANT ALL PRIVILEGES ON $WSO2_UM_DB.* TO '$DB_USERNAME'@'%';
        SOURCE $DB_SCRIPTS_PATH/mysql5.7.sql;
        USE $WSO2_REG_DB;
        GRANT ALL PRIVILEGES ON $WSO2_REG_DB.* TO '$DB_USERNAME'@'%';
        SOURCE $DB_SCRIPTS_PATH/mysql5.7.sql;
        USE $WSO2_ANALYTICS_EVENT_STORE;
        GRANT ALL PRIVILEGES ON $WSO2_ANALYTICS_EVENT_STORE.* TO '$DB_USERNAME'@'%';
        USE $WSO2_ANALYTICS_PROCESSED_DATA_STORE;
        GRANT ALL PRIVILEGES ON $WSO2_ANALYTICS_PROCESSED_DATA_STORE.* TO '$DB_USERNAME'@'%';
        USE $WSO2_AM_STATS_DB;
        GRANT ALL PRIVILEGES ON $WSO2_AM_STATS_DB.* TO '$DB_USERNAME'@'%';"
    else
        mysql -h $DB_HOST -P $DB_PORT -u $DB_USERNAME -p$DB_PASSWORD \
        -e "USE $WSO2_UM_DB;
        GRANT ALL PRIVILEGES ON $WSO2_UM_DB.* TO '$DB_USERNAME'@'%';
        SOURCE $DB_SCRIPTS_PATH/mysql.sql;
        USE $WSO2_REG_DB;
        GRANT ALL PRIVILEGES ON $WSO2_REG_DB.* TO '$DB_USERNAME'@'%';
        SOURCE $DB_SCRIPTS_PATH/mysql.sql;
        USE $WSO2_ANALYTICS_EVENT_STORE;
        GRANT ALL PRIVILEGES ON $WSO2_ANALYTICS_EVENT_STORE.* TO '$DB_USERNAME'@'%';
        USE $WSO2_ANALYTICS_PROCESSED_DATA_STORE;
        GRANT ALL PRIVILEGES ON $WSO2_ANALYTICS_PROCESSED_DATA_STORE.* TO '$DB_USERNAME'@'%';
        USE $WSO2_AM_STATS_DB;
        GRANT ALL PRIVILEGES ON $WSO2_AM_STATS_DB.* TO '$DB_USERNAME'@'%';"
    fi
    echo ">> Tables created!"
}

init_sqlserver_rds() {
    echo ">> Setting up SQLServer databases ..."
    echo ">> Creating databases..."
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $WSO2_UM_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $WSO2_REG_DB"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $WSO2_ANALYTICS_EVENT_STORE"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $WSO2_ANALYTICS_PROCESSED_DATA_STORE"
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -Q "CREATE DATABASE $WSO2_AM_STATS_DB"
    echo ">> Databases created!"

    echo ">> Creating tables..."
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $WSO2_UM_DB -i $DB_SCRIPTS_PATH/mssql.sql
    sqlcmd -S $DB_HOST -U $DB_USERNAME -P $DB_PASSWORD -d $WSO2_REG_DB -i $DB_SCRIPTS_PATH/mssql.sql
    echo ">> Tables created!"
}

setup_wum_updated_pack() {

    sudo -u ${USERNAME} /usr/local/wum/bin/wum add ${WUM_PRODUCT_NAME} -y
    sudo -u ${USERNAME} /usr/local/wum/bin/wum update ${WUM_PRODUCT_NAME}

    mkdir -p ${INSTALLATION_DIR}
    chown -R ${USERNAME} ${INSTALLATION_DIR}
    echo ">> Copying WUM updated ${WUM_PRODUCT_NAME} to ${INSTALLATION_DIR}"
    sudo -u ${USERNAME} unzip ${WUM_PRODUCT_DIR}/$(ls -t ${WUM_PRODUCT_DIR} | grep .zip | head -1) -d ${INSTALLATION_DIR}
}

main() {
    setup_wum_updated_pack
    if [ $DB_ENGINE = "mysql" ]; then
    init_mysql_rds
    elif [ $DB_ENGINE = "sqlserver-ex" ]; then
    init_sqlserver_rds
    fi
}

main