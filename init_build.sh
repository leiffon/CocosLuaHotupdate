#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $1 ]; then
    DIR=$1
fi
SCRIPTS_DIR=$DIR/.data/src
DEST_DIR=$DIR/.data
TARGET_FILE=init

COMPILE_BIN=$QUICK_V3_ROOT/quick/bin/compile_scripts.sh 

mkdir $DEST_DIR
mkdir $SCRIPTS_DIR

# 编译游戏脚本文件
file32=$TARGET_FILE"32.zip"
file64=$TARGET_FILE"64.zip"

rm $SCRIPTS_DIR/*.lua
rm -f $DEST_DIR/$file32
rm -f $DEST_DIR/$file64

cp -f $DIR/src/*.lua $SCRIPTS_DIR/

# TODO: 修改签名 -es的参数
SIGN=YOUR_SIGN
KEY=SET_YOUR_PWD
ENCRYPT_COMMAND=" -e xxtea_zip -ek $KEY -es $SIGN "


$COMPILE_BIN -b 32 -i $SCRIPTS_DIR -o $DEST_DIR/$file32 $ENCRYPT_COMMAND
$COMPILE_BIN -b 64 -i $SCRIPTS_DIR -o $DEST_DIR/$file64 $ENCRYPT_COMMAND
