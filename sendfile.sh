#!/bin/bash
#-------------------------------------------------------------------------------------------------------
#从当前机器发布文件到远程机器,如果是分布式机器,以一台机器为主节点通过sersync同步到其它节点
#
#
#参数说明
#	发布
#$1:执行动作send
#$2:远程目标机器ip
#$3:远程目标机器端口
#$4:当前机器发布根目录
#$5:远程目标机器发布根目录
#$6:远程目标机器备份根目录
#$7:发布版本号
#$8:文件列表 多个文件或者目录使用","隔开

#
#
#	回滚
#$1:执行动作roll
#$2:远程目标机器ip
#$3:远程目标机器端口
#$4:当前机器发布根目录
#$5:远程目标机器发布根目录
#$6:远程目标机器备份根目录
#$7:回滚版本号
#----------------------------------------------------------------------------------------------------

source /etc/profile
umask 022

readonly TARGET_IP=$2						#远程目标机器ip
readonly TARGET_PORT=$3						#远程目标机器ip
readonly USER=www							#执行远程shell命令用户
readonly SOURCE_ROOT=$4						#当前机器发布根目录
readonly TARGET_ROOT=$5						#远程目标机器发布目录
readonly BACKUP_ROOT=$6						#远程目标机器备份路径

readonly execssh="/usr/bin/ssh -p ${TARGET_PORT} -o StrictHostKeyChecking=no ${USER}@${TARGET_IP}" #在远程目标机器执行shell命令

#发布
function send(){
	IFS=","
	error=0
	aFile=($1)
	for file in ${aFile[@]}
	do
		if [ ! -e "${SOURCE_ROOT}/${file}" ];then
			fileList+={$file}
			error=1
		fi
	done

	if [ "${error}" != 0 ];then
		echo "file list is not exists in ${SOURCE_ROOT}"
		echo $fileList
		exit 1
	fi

	eval "${execssh} ${TARGET_ROOT}/cron/sendfile.sh backup ${1} ${2} ${TARGET_ROOT} ${BACKUP_ROOT}"
	
	if [ "$?" == 0 ];then
		cd ${SOURCE_ROOT}
		fileList=$(echo "${1}" | tr "," " ")
		#/usr/bin/rsync -avzR -e ssh ${fileList} ${USER}@${TARGET_IP}:${TARGET_ROOT}
		eval "/usr/bin/rsync -avzR '-e ssh -p ${TARGET_PORT}' ${fileList} ${USER}@${TARGET_IP}:${TARGET_ROOT}"
	else
		echo "back up faild!!!"
		exit 2
	fi
	exit 0
}

#回滚
function roll(){
	$execssh "tar zxf ${BACKUP_ROOT}/${1}.bak.tar.gz -C ${TARGET_ROOT}"
	echo 'ok'
}

#备份
function backup(){
	target_root=$3
	back_root=$4
	cd ${target_root}
	IFS=","
	aFile=($1)
	fileList=""
	for file in ${aFile[@]}
	do
		if [ -e "${target_root}/${file}" ];then
			fileList+="$file "
		fi
	done
	if [ -n "${fileList}" ];then
		if [ ! -d ${back_root} ];then
			mkdir -p ${back_root}
			if [ "$?" != 0 ];then
				echo "mkdir backup dir ${back_root} fail"
				exit 1
			fi
		fi
		tar czf ${back_root}/${2}.bak.tar.gz $1
		if [ "$?" == 0 ];then
			echo "backup file ${back_root}/${2}.bak.tar.gz!"
		fi 
	fi
}

function argsCheck(){
	if [ -z $2 ] || [ -z $3 ] || [ -z $4 ] || [ -z $5 ] || [ -z $6 ] || [ -z $7 ];then
		echo "useage ${0} send|roll TARGET_IP TARGET_PORT SOURCE_ROOT TARGET_ROOT BACKUP_ROOT VER"
		exit 1
	fi
	if [ ! -d $4 ];then
		echo "SOURCE_ROOT ${SOURCE_ROOT} is not exsists!"
		exit 2
	fi
}

case $1 in
	"send")
		argsCheck "$@"
		send $8 $7 #文件列表版本号
	;;
	
	"backup")
		backup $2 $3 $4 $5
	;;
	
	"roll")
		argsCheck "$@"
		roll $7 #版本号
	;;
	
	*)
	echo "useage ${0} send|roll TARGET_IP TARGET_PORT SOURCE_ROOT TARGET_ROOT BACKUP_ROOT VER"
	;;
esac



