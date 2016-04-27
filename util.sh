#!/bin/bash

WORKDIR=$(cd `dirname $0`; pwd)
cd ${WORKDIR}
_DATE=$(date +"%Y%m%d")

function quit() {
  if [ $1 -ne 0 ];then
    echo "[error] $2"
    exit 1
  fi
}

function show_usage() {
  case $1 in
    compress|upload)
  cat <<EOF
Usage: ./util.sh $1 <os_type> [YYYYMMDD]
<os_type>:
  linux
  mac
  arm
EOF
    ;;
  list)
  cat <<EOF
Usage: ./util.sh list <target> [YYYYMMDD]
<target>
  local
  remote
EOF
    ;;
  *)
  cat <<EOF
Usage: ./util.sh <action>
<action>
  compress
  upload
  list
EOF
    ;;
  esac
  exit 1
}

function show_title() {
  cat <<EOF

################################################################################
  $1
################################################################################
EOF
}
function ensure_dir() {
  if [ "$1" == "" ];then
    _date=${_DATE}
  else
    _date=$1
  fi
  mkdir -p ready/{linux,mac,arm}
  mkdir -p upload/${_date}/{linux,mac,arm}
}

################################################################################
# compress hyper cli
# src: ready/$1
# target: upload/${_DATE}/$1
################################################################################
function compress() {
  os_type=$1
  if [ "$2" == "" ];then
    _date=${_DATE}
  else
    _date=$2
  fi
  ensure_dir ${_date}
  show_title "start compress hyper cli"

  # kill original compress
  case ${os_type} in
    linux) tag="x86_64";;
    mac)   tag="mac"   ;;
    arm)   tag="arm"   ;;
    *)  tag="";;
  esac
  ps aux | grep "util.sh upload ${os_type}" | grep -vE "(grep|$$)" | awk '{print $2}' | xargs -I pid sudo kill -9 pid
  ps aux | grep "aws --profile hyper s3.*${tag}" | grep -vE "(grep|$$)" | awk '{print $2}' | xargs -I pid sudo kill -9 pid


  BIN_TGT_DIR="${WORKDIR}/upload/${_date}/${os_type}"
  BIN_SRC_DIR="${WORKDIR}/ready/${os_type}"
  #check source file
  [ ! -f ${BIN_SRC_DIR}/hyper-${os_type} ] && quit "1" "${BIN_SRC_DIR}/hyper-${os_type} not exist"
  [ ! -f ${BIN_SRC_DIR}/checksum ] && quit "1" "${BIN_SRC_DIR}/checksum not exist"
  #check checksum
  CHECKSUM=$(cat ${BIN_SRC_DIR}/checksum | awk '{print $1}')
  [ "${CHECKSUM}" == "" ] && quit "1" "${CHECKSUM} should not be empty"

  #ensure target dir
  [ -d ${BIN_TGT_DIR} ] && rm -rf ${BIN_TGT_DIR}
  mkdir -p ${BIN_TGT_DIR}

  #copy src to target
  cp ${BIN_SRC_DIR}/hyper-${os_type} ${BIN_TGT_DIR}/hyper
  cp ${BIN_SRC_DIR}/checksum ${BIN_TGT_DIR}/
  cd ${BIN_TGT_DIR}
  chmod +x hyper

  #verify checksum
  case ${os_type} in
    linux)
      _CHECKSUM=$(md5sum hyper| awk '{print $1}')
      ;;
    mac)
      _CHECKSUM=$(md5 hyper| awk '{print $NF}')
      ;;
    arm)
      _CHECKSUM=$(md5sum hyper| awk '{print $1}')
      ;;
  esac
  [ "${CHECKSUM}" != "${_CHECKSUM}" ] && quit 1 "original checksum is '${CHECKSUM}', but current checksum is '${_CHECKSUM}'"

  n=0
  flie_list=()
  #tar
  case ${os_type} in
    linux)
      for i in latest 1.10
      do
        echo "compress to hyper-${i}-x86_64.tar.gz ..."
        tar czvf hyper-${i}-x86_64.tar.gz hyper
        md5sum hyper-${i}-x86_64.tar.gz > hyper-${i}-x86_64.tar.gz.md5
        file_list[$n]="hyper-${i}-x86_64.tar.gz"
        n=$((n+1))
      done
      ;;
    mac)
      for i in latest 1.10
      do
        echo "compress to hyper-${i}-mac.bin.zip ..."
        zip hyper-${i}-mac.bin.zip hyper
        md5 hyper-${i}-mac.bin.zip > hyper-${i}-mac.bin.zip.md5
        file_list[$n]="hyper-${i}-mac.bin.zip"
        n=$((n+1))
      done
      ;;
    arm)
      for i in latest 1.10
      do
        echo "compress to hyper-${i}-arm.tar.gz ..."
        tar czvf hyper-${i}-arm.tar.gz hyper
        md5sum hyper-${i}-arm.tar.gz > hyper-${i}-arm.tar.gz.md5
        file_list[$n]="hyper-${i}-arm.tar.gz"
        n=$((n+1))
      done
      ;;
  esac
  echo "---------- ${BIN_TGT_DIR} ----------"
  ls -l ${BIN_TGT_DIR}
}

################################################################################
# upload hyper cli packate to s3
# src: upload/${_date}/$1
# target: s3://mirror-hyper-install
################################################################################
function upload() {
  os_type=$1
  if [ "$2" == "" ];then
    _date=${_DATE}
  else
    _date=$2
  fi
  ensure_dir ${_date}
  BIN_TGT_DIR="${WORKDIR}/upload/${_date}/${os_type}"
  [ ! -d ${BIN_TGT_DIR}  ] && quit 1 "dir ${BIN_TGT_DIR} not found,skip upload"

  show_title "start upload hyper cli package to s3"
  cd ${BIN_TGT_DIR}
  #delete hyper
  [ -f hyper ] && rm -rf hyper

  #sync local to mirror s3
  show_title "start sync local '${BIN_TGT_DIR}' to 's3://mirror-hyper-install/hyperserve-cli-bak/${_date}/${os_type}'"
  s3_sync ${BIN_TGT_DIR} s3://mirror-hyper-install/hyperserve-cli-bak/${_date}/${os_type}

  show_title "start copy hyper cli package from 's3://mirror-hyper-install/hyperserve-cli-bak/${_date}/${os_type}'  to s3://mirror-hyper-install/"
  for f in $(ls hyper-*)
  do
    echo "-------------------------- ${f} --------------------------"
    s3_cp s3://mirror-hyper-install/hyperserve-cli-bak/${_date}/${os_type}/${f} s3://mirror-hyper-install/${f}
  done

  show_title "start copy hyper cli package from 's3://mirror-hyper-install/hyperserve-cli-bak/${_date}/${os_type}'  to s3://hyper-install/"
  for f in $(ls hyper-*)
  do
    echo "-------------------------- ${f} --------------------------"
    s3_cp s3://mirror-hyper-install/hyperserve-cli-bak/${_date}/${os_type}/${f} s3://hyper-install/${f}
  done
}

function s3_sync() {
  time aws --profile hyper s3 sync $1 $2 --acl=public-read
}

function s3_cp() {
  time aws --profile hyper s3 cp $1 $2 --acl=public-read
}

function list_local() {
  if [ "$1" == "" ];then
    _date=${_DATE}
  else
    _date=$1
  fi
  BIN_TGT_DIR="${WORKDIR}/upload/${_date}"
  [ ! -d ${BIN_TGT_DIR} ] && quit 1 "${BIN_TGT_DIR} not exist"

  for os_type in $(ls ${BIN_TGT_DIR})
  do
    echo
    echo "=============== [ ${BIN_TGT_DIR}/${os_type} ] ==============="
    ls -l ${BIN_TGT_DIR}/${os_type}
  done
}

function list_remote() {
  if [ "$1" == "" ];then
    _date=${_DATE}
  else
    _date=$1
  fi

  show_title "[mirror] s3://mirror-hyper-install/hyperserve-cli-bak/${_date}/"
  aws --profile hyper s3 ls s3://mirror-hyper-install/hyperserve-cli-bak/${_date}/ --human-readable --summarize

  show_title "[mirror] s3://mirror-hyper-install/"
  aws --profile hyper s3 ls s3://mirror-hyper-install/ --human-readable --summarize

  show_title "s3://hyper-install/"
  aws --profile hyper s3 ls s3://hyper-install/ --human-readable --summarize
}

#########################################################################################
# main
#########################################################################################
case $1 in
  compress)
      case $2 in
        linux|mac|arm)  compress $2 $3 ;;
        '')     show_usage "compress" ;;
        *)      quit 1 "unsupport os type '$1', only support linux/mac/arm" ;;
      esac
    ;;
  upload)
      case $2 in
        linux|mac|arm)  upload $2 $3;;
        '')     show_usage "upload" ;;
        *)      quit 1 "unsupport os type '$1', only support linux/mac/arm" ;;
      esac
    ;;
  list)
      case $2 in
        local)  list_local $3;;
        remote) list_remote $3;;
        *)      show_usage "list";;
      esac
      ;;
  *)
    show_usage ""
    ;;
esac
