# 注意：请先执行 game_build.sh.sh 编译脚本代码
# 注意：请先执行 game_build.sh.sh 编译脚本代码
# 注意：请先执行 game_build.sh.sh 编译脚本代码

# 这个脚本是用来刷新XCODE中的资源和代码文件的，
# 因为一个已知的XCODE的BUG，在编译时它不知道去更新资源文件
# 这个脚本不能直接执行，只能把它的内容，复制到 Build Phases中的 Run Script 段中

_GAME_BUILD_PATH="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"
echo "_GAME_BUILD_PATH: $_GAME_BUILD_PATH"
echo "PWD: $PWD"

_DEST_RES_PATH="$_GAME_BUILD_PATH/res/"
_DEST_SRC_PATH="$_GAME_BUILD_PATH/src/"

rm -rf "$_DEST_RES_PATH"
rm -rf "$_DEST_SRC_PATH"
mkdir -p "$_DEST_RES_PATH"

rsync -av ${SRCROOT}/../../../build/res/ "$_DEST_RES_PATH"
