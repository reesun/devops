#!/bin/bash

MASTER_DIR=/var/lib/mysql/master
SLAVE_DIR=/var/lib/mysql/slave

## First we could rm the existed container
docker rm -f master
docker rm -f slave

## Rm the existed directory
rm -rf $MASTER_DIR
rm -rf $SLAVE_DIR

## Start instance
docker run --name master -v /etc/master.cnf:/etc/mysql/my.cnf -v $MASTER_DIR:/var/lib/mysql  --net=host -e MYSQL_ROOT_PASSWORD=123456 -d mysql:5.6.34
docker run --name slave -v /etc/slave.cnf:/etc/mysql/my.cnf -v $SLAVE_DIR:/var/lib/mysql --net=host -e MYSQL_ROOT_PASSWORD=123456 -d mysql:5.6.34
## Creating a User for Replication
docker stop master slave
docker start master slave

sleep 3

docker exec -it master mysql -S /var/lib/mysql/mysql.sock -e "CREATE USER 'repl'@'127.0.0.1' IDENTIFIED BY 'repl';GRANT REPLICATION SLAVE ON *.* TO 'repl'@'127.0.0.1';"

## Obtaining the Replication Master Binary Log Coordinates
master_status=`docker exec -it master mysql -S /var/lib/mysql/mysql.sock -e "show master status\G"`
master_log_file=`echo "$master_status" | awk  'NR==2{print substr($2,1,length($2)-1)}'`
master_log_pos=`echo "$master_status" | awk 'NR==3{print $2}'`
master_log_file="'""$master_log_file""'"

## Setting Up Replication Slaves
docker exec -it slave mysql -S /var/lib/mysql/mysql.sock -e "CHANGE MASTER TO MASTER_HOST='127.0.0.1',MASTER_PORT=3306,MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE=$master_log_file,MASTER_LOG_POS=$master_log_pos;"docker exec -it slave mysql -S /var/lib/mysql/mysql.sock -e "start slave;"
docker exec -it slave mysql -S /var/lib/mysql/mysql.sock -e "show slave status\G"

## Creates shortcuts
grep "alias master" /etc/profile
if [ $? -eq 1 ];then
    echo 'alias mysql="docker exec -it master mysql"' >> /etc/profile
    echo 'alias master="docker exec -it master mysql -h 127.0.0.1 -P3306"' >> /etc/profile
    echo 'alias slave="docker exec -it master mysql -h 127.0.0.1 -P3307"' >> /etc/profile
    source /etc/profile
fi
