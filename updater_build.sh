#!/bin/sh

# 这是编译更新模块 updater**.zip 的快捷工具，仅用bytecode打包不加密

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $1 ]; then
	DIR=$1
fi

# TODO: 修改下面的目录UPDATER_DIR为你的updater模块所在的实际目录
UPDATER_DIR=$QUICK_V3_ROOT/hotupdater
UPDATER_SCRIPTS_DIR=$UPDATER_DIR/.
UPDATER_DEST_DIR=$UPDATER_DIR/.
UPDATER_TARGET_FILE=updater

UPDATER_COMPILE_BIN=$QUICK_V3_ROOT/quick/bin/compile_scripts.sh

# 编译更新模块脚本文件
file32=$UPDATER_DEST_DIR/$UPDATER_TARGET_FILE"32.zip"
file64=$UPDATER_DEST_DIR/$UPDATER_TARGET_FILE"64.zip"

rm -f $file32
rm -f $file64
$UPDATER_COMPILE_BIN -b 32 -i $UPDATER_SCRIPTS_DIR -o $file32
$UPDATER_COMPILE_BIN -b 64 -i $UPDATER_SCRIPTS_DIR -o $file64

rm -f $UPDATER_DEST_DIR/preupdate32.zip
rm -f $UPDATER_DEST_DIR/preupdate64.zip
$UPDATER_COMPILE_BIN -b 32 -i $DIR/preupdate -o $UPDATER_DEST_DIR/preupdate32.zip
$UPDATER_COMPILE_BIN -b 64 -i $DIR/preupdate -o $UPDATER_DEST_DIR/preupdate64.zip

# 拷贝updater**.zip到工程res目录下（如仅需编译本updater模块，注释以下代码即可）
DEST_DIR=$DIR/res
echo "cp $UPDATER_DIR/*.zip $DEST_DIR/"
cp -f $UPDATER_DIR/*.zip $DEST_DIR/
