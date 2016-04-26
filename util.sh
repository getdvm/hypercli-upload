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
    upload)
  cat <<EOF
Usage: ./util.sh upload <os_type>
<os_type>:
  linux
  mac
  arm
EOF
    ;;
  list)
  cat <<EOF
Usage: ./util.sh list [YYYYMMDD]
EOF
    ;;
  *)
  cat <<EOF
Usage: ./util.sh <action>
<action>
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
  mkdir -p ready/{linux,mac,arm}
  mkdir -p upload/${_DATE}/{linux,mac,arm}
}

function process() {
  os_type=$1
  show_title "start compress hyper cli"

  # kill original process
  case ${os_type} in
    linux) tag="x86_64";;
    mac)   tag="mac"   ;;
    arm)   tag="arm"   ;;
    *)  tag="";;
  esac
  ps aux | grep "util.sh upload ${os_type}" | grep -vE "(grep|$$)" | awk '{print $2}' | xargs -I pid sudo kill -9 pid
  ps aux | grep "aws --profile hyper s3.*${tag}" | grep -vE "(grep|$$)" | awk '{print $2}' | xargs -I pid sudo kill -9 pid


  BIN_TGT_DIR="${WORKDIR}/upload/${_DATE}/${os_type}"
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
  upload "${BIN_TGT_DIR}" "${file_list}"
}

function upload() {
  BIN_TGT_DIR=$1
  file_list=$2
  show_title "start upload hyper cli package to s3"
  for f in ${file_list[@]}
  do
    echo "-------------------------- ${f} --------------------------"
    #
    cp_local_to_s3 ${BIN_TGT_DIR}/${f}.md5 ${_DATE}/${f}.md5
    #
    hyper_checksum_file=${f/.tar.gz/}
    hyper_checksum_file=${hyper_checksum_file/.bin.zip/}.checksum
    cp_local_to_s3 ${BIN_TGT_DIR}/checksum ${_DATE}/${hyper_checksum_file}
    #
    cp_local_to_s3 ${BIN_TGT_DIR}/${f} ${_DATE}/${f}
  done

  show_title "start mv hyper cli package from mirror-hyper-install to hyper-install"
  for f in ${file_list[@]}
  do
    echo "-------------------------- ${f} --------------------------"
    #
    cp_s3_to_s3 ${_DATE} ${f}.md5
    #
    # hyper_checksum_file=${f/.tar.gz/}
    # hyper_checksum_file=${hyper_checksum_file/.bin.zip/}.checksum
    # cp_s3_to_s3 ${_DATE} ${hyper_checksum_file}
    #
    cp_s3_to_s3 ${_DATE} ${f}
  done

}

function cp_local_to_s3() {
  time aws --profile hyper s3 cp $1 s3://mirror-hyper-install/hyperserve-cli-bak/$2
}

function cp_s3_to_s3() {
  time aws --profile hyper s3 cp s3://mirror-hyper-install/hyperserve-cli-bak/$1/$2 s3://hyper-install/$2
}

function list_s3_by_date() {
  show_title "[mirror] s3://mirror-hyper-install/hyperserve-cli-bak/$1/"
  aws --profile hyper s3 ls s3://mirror-hyper-install/hyperserve-cli-bak/$1/

  show_title "[mirror] s3://mirror-hyper-install/"
  aws --profile hyper s3 ls s3://mirror-hyper-install/

  show_title "s3://hyper-install/"
  aws --profile hyper s3 ls s3://hyper-install/
}

#########################################################################################
# main
#########################################################################################
ensure_dir

case $1 in
  upload)
      case $2 in
        linux)  process linux ;;
        mac)    process mac ;;
        arm)    process arm ;;
        '')     show_usage "upload" ;;
        *)      quit 1 "unsupport os type '$1', only support linux/mac/arm" ;;
      esac
    ;;
  list)
      if [ $# -eq 1 ];then
        list_s3_by_date ${_DATE}
      elif [ $# -eq 2 ];then
        list_s3_by_date $2
      else
        show_usage "list"
      fi
      ;;
  *)
    show_usage ""
    ;;
esac
