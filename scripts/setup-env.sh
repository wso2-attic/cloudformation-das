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

# This script setup environment for WSO2 product deployment
readonly USERNAME=$2
readonly WUM_USER=$4
readonly WUM_PASS=$6
readonly JDK=$8
readonly DB_ENGINE=${10}
readonly HOME=/home/${USERNAME}
readonly LIB_DIR=/home/${USERNAME}/lib
readonly TMP_DIR=/tmp

install_packages() {
    apt-get update -y
    apt install git -y
}

get_java_home() {

    JAVA_HOME=${ORACLE_JDK8}
    if [[ ${JDK} = "ORACLE_JDK9" ]]; then
        JAVA_HOME=${ORACLE_JDK9}
    elif [[ ${JDK} = "ORACLE_JDK10" ]]; then
        JAVA_HOME=${ORACLE_JDK10}
    elif [[ ${JDK} = "OPEN_JDK8" ]]; then
        JAVA_HOME=${OPEN_JDK8}
    elif [[ ${JDK} = "OPEN_JDK9" ]]; then
        JAVA_HOME=${OPEN_JDK9}
    elif [[ ${JDK} = "OPEN_JDK10" ]]; then
        JAVA_HOME=${OPEN_JDK10}
    fi

    echo ${JAVA_HOME}
}

setup_java() {

    echo "Setting up java"
    #Default environment variable file is /etc/profile

    ENV_VAR_FILE=/etc/environment

    echo JDK_PARAM=${JDK} >> /home/ubuntu/java.txt
    echo ORACLE_JDK9=${ORACLE_JDK9} >> /home/ubuntu/java.txt
    source ${ENV_VAR_FILE}
    JAVA_HOME=$(get_java_home)
    echo "JAVA_HOME=$JAVA_HOME" >> ${ENV_VAR_FILE}
    source ${ENV_VAR_FILE}
}

install_wum() {

    echo "127.0.0.1 $(hostname)" >> /etc/hosts
    wget -P ${LIB_DIR} https://product-dist.wso2.com/downloads/wum/1.0.0/wum-1.0-linux-x64.tar.gz
    cd /usr/local/
    tar -zxvf "${LIB_DIR}/wum-1.0-linux-x64.tar.gz"
    chown -R ${USERNAME} wum/
    
    local is_path_set=$(grep -r "usr/local/wum/bin" /etc/profile | wc -l  )
    echo ">> Adding WUM installation directory to PATH ..."
    if [ ${is_path_set} = 0 ]; then
        echo ">> Adding WUM installation directory to PATH variable"
        echo "export PATH=\$PATH:/usr/local/wum/bin" >> /etc/profile
    fi
    source /etc/profile
    echo ">> Initializing WUM ..."
    sudo -u ${USERNAME} /usr/local/wum/bin/wum init -u ${WUM_USER} -p ${WUM_PASS}
}

install_jdbc_client() {
    if [ $DB_ENGINE = "mysql" ]; then
        get_mysql_jdbc_driver
    elif [ $DB_ENGINE = "sqlserver-ex" ]; then
        get_sqlserver_jdbc_driver
    fi
}

get_mysql_jdbc_driver() {
    echo MYSQL_DB_ENGINE=${DB_ENGINE} >> /home/ubuntu/java.txt
    wget -O ${TMP_DIR}/jdbc-connector.jar http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.44/mysql-connector-java-5.1.44.jar
}

get_sqlserver_jdbc_driver() {
    echo MSSQL_DB_ENGINE=${DB_ENGINE} >> /home/ubuntu/java.txt
    wget -O ${TMP_DIR}/jdbc-connector.jar http://central.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/6.1.0.jre8/mssql-jdbc-6.1.0.jre8.jar
}

echo_params() {
    echo 2=${USERNAME} >> /home/ubuntu/java.txt
    echo 4=${WUM_USER} >> /home/ubuntu/java.txt
    echo 8=${JDK} >> /home/ubuntu/java.txt
    echo 10=${DB_ENGINE} >> /home/ubuntu/java.txt
}

main() {

    mkdir -p ${LIB_DIR}
    echo_params
    install_packages
    setup_java
    install_wum
    install_jdbc_client
    echo "Done!"
}

main
