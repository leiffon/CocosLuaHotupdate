#!/bin/bash
#发布新的打包版本
proj_dir=$(cd `dirname $0`; pwd)
echo $proj_dir

if [ ! $1 ]; then
    echo "用法：./new_release.sh r|t(发布｜测试环境标识)"
    exit;
fi

$proj_dir/updater_build.sh
$proj_dir/framework_build.sh
$proj_dir/game_build.sh $1

