#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTS_DIR=$DIR/.data/src
DEST_DIR=$DIR/.data
TARGET_FILE=game

if [ ! $1 ]; then
    echo "用法：./game_build.sh r|t(发布｜测试环境标识)"
    exit;
fi

COMPILE_BIN=$QUICK_V3_ROOT/quick/bin/compile_scripts.sh 

mkdir $DEST_DIR
rm -rf $SCRIPTS_DIR
mkdir $SCRIPTS_DIR
cp -rf $DIR/src/app $SCRIPTS_DIR


# 编译游戏脚本文件
file32=$TARGET_FILE"32.zip"
file64=$TARGET_FILE"64.zip"
rm -f $DEST_DIR/$file32
rm -f $DEST_DIR/$file64

# TODO: 在这里修改你的项目的加密密码，不得超过16位
SIGN=YOUR_SIGN
KEY=SET_YOUR_PWD
ENCRYPT_COMMAND=" -e xxtea_zip -ek $KEY -es $SIGN "

$COMPILE_BIN -b 32 -i $SCRIPTS_DIR -o $DEST_DIR/$file32 $ENCRYPT_COMMAND
$COMPILE_BIN -b 64 -i $SCRIPTS_DIR -o $DEST_DIR/$file64 $ENCRYPT_COMMAND
rm -rf $SCRIPTS_DIR

# 编译lua入口文件
source $DIR/init_build.sh $DIR

build_path=$DIR"/build/"
rm -rf $build_path
mkdir -p $build_path

python $DIR/encrypt_res.py $KEY $SIGN

cp -rf "$DIR"/.data/*32.zip $build_path/res/
cp -rf "$DIR"/.data/*64.zip $build_path/res/

python $DIR/make_update_files.py $1
