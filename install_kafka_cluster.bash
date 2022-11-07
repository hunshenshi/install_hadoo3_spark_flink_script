#!/usr/bin/env bash

mirrorServer=https://dist.apache.org/repos/dist/release
kafkaVersion=2.8.2

cluster=$1
eval $(echo $cluster | awk '{split($0, array, ",");for(i in array)print "host_array["i"]="array[i]}')

## local_ip replace localhost in config file
local_host="`hostname`"
local_ip=`host $local_host 2>/dev/null | awk '{print $NF}'`

java_home=`echo $JAVA_HOME`

## current_path replace data_path in config file
current_path=`pwd`
project_root_path=`cd ${current_path}/.. && pwd`
#cd ${current_path}
#project_root_path=${current_path}/../..

echo $project_root_path

cd $project_root_path/deps

echo =========================================================
echo "Install kafka ($kafkaVersion)"
echo =========================================================
kafka_name=kafka

kafka_home=$project_root_path/deps/${kafka_name}
if [ ! -d "$kafka_name" ]; then
    if [ ! -f "kafka_2.12-$kafkaVersion.tgz" ]; then
        wget $mirrorServer/kafka/$kafkaVersion/kafka_2.12-$kafkaVersion.tgz
    fi
    tar -zxvf kafka_2.12-$kafkaVersion.tgz
    mv kafka_2.12-$kafkaVersion ${kafka_name}
    cp -r ${current_path}/kafka/* ${kafka_home}/
    mkdir -p ${kafka_home}/kafka-data/kafka-logs
    mkdir -p ${kafka_home}/zookeeper-data/data
    mkdir -p ${kafka_home}/zookeeper-data/log
    echo "Changing hadoop config files..."
    cd ${kafka_name}/config
    #find . -type f -print0 | xargs -0 sed -i "s/localhost/$local_ip/g"
    find . -type f -print0 | xargs -0 sed -i "s#data_path#$kafka_home#g"
    count=0
    for item in ${host_array[@]}; do
        count=$(($count+1))
        find . -type f -print0 | xargs -0 sed -i "s/host0$count/$item/g"
    done
    cd ../../..
    echo "export KAFKA_HOME=${kafka_home}" > ${kafka_home}/bashrc
    echo "export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac))))" >> ${kafka_home}/bashrc
    cat ${current_path}/bashrc/kafka_bashrc >> ${kafka_home}/bashrc
fi
source ${kafka_home}/bashrc

echo ========================
echo Install cluster
echo ========================

for(( i=2;i<=${#host_array[@]};i++)) ; do
#    echo ssh ${host_array[i]} "mkdir -p $project_root_path/deps"
    ssh ${host_array[i]} "mkdir -p $project_root_path/deps"
    ssh ${host_array[i]} "rm -rf ${kafka_home}"
    cp -r ${kafka_home} ${kafka_home}0$i
    cd ${kafka_home}0$i/config
    echo `pwd`
    find . -type f -print0 | xargs -0 sed -i "s/brokerID/$i/g"
    cd ../..
    echo `pwd`
    echo "rsync -r ${kafka_home}0$i ${host_array[i]}:$project_root_path/deps/"
    echo "yes" | rsync -r ${kafka_home}0$i ${host_array[i]}:$project_root_path/deps/
    
    ssh ${host_array[i]} "mv ${kafka_home}0$i ${kafka_home}"
    ssh ${host_array[i]} "echo $i > ${kafka_home}/zookeeper-data/data/myid"
    ssh ${host_array[i]} "source ${kafka_home}/bashrc && ${kafka_home}/bin/zookeeper-server-start.sh -daemon ${kafka_home}/config/zookeeper.properties"
    ssh ${host_array[i]} "source ${kafka_home}/bashrc && ${kafka_home}/bin/kafka-server-start.sh -daemon ${kafka_home}/config/server.properties"
done

cd ${kafka_home}/config
find . -type f -print0 | xargs -0 sed -i "s/brokerID/1/g"
echo 1 > ${kafka_home}/zookeeper-data/data/myid

source ${kafka_home}/bashrc
${kafka_home}/bin/zookeeper-server-start.sh -daemon ${kafka_home}/config/zookeeper.properties
${kafka_home}/bin/kafka-server-start.sh -daemon ${kafka_home}/config/server.properties

