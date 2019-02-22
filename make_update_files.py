#!/usr/bin/env python2.7
#coding:utf-8
import sys, os, json, time, hashlib
import subprocess
import shutil
from copy import deepcopy

BASE_PATH = os.path.dirname(os.path.realpath(__file__)) + os.sep

# 文件扩展名
def file_extension(path):  
  return os.path.splitext(path)[1]

def md5(fname):
  hash_md5 = hashlib.md5()
  with open(fname, "rb") as f:
    for chunk in iter(lambda: f.read(4096), b""):
      hash_md5.update(chunk)
  return hash_md5.hexdigest()

# 计算文件MD5值
def calc_md5(path):
  return md5(path)

# 删除文件
def removeFile(filePath):
  assert(filePath)
  if os.path.isfile(filePath):
    os.remove(filePath)

# 删除目录
def removePath(path):
  assert(path)
  if path == "/" or path == ".":
    print "Can't do this action: remove whole ", path
    return
  if os.path.isdir(path):
    shutil.rmtree(path)

# 拷贝文件
def copyFile(source, dest):
  assert(source and dest)
  shutil.copy(source, dest)

# 拷贝目录
def copyPath(sourcePath, destPath):
  assert(sourcePath and destPath)
  shutil.copytree(sourcePath, destPath)

# 遍历文件夹
def listPathByHandler(rootDir, handler):
  for lists in os.listdir(rootDir): 
    path = os.path.join(rootDir, lists)
    # print path
    if os.path.isdir(path):
      listPathByHandler(path, handler)
    else:
      handler(path)

# 分析lua的配置文件，取出其中的 VERSION_NAME GAME_ID BRANCH_ID 这几项
# 注意不能分析复杂的配置项，这里只是为了读出数字和字符串的配置
def readLuaConfig(filename, key):
  if not os.path.isfile(filename):
    return None

  file = open(filename)
  while 1:
    line = file.readline()
    if not line:
      break
    else:
      pos = line.find("--")
      line = line.replace(line[pos:], "")  # 清除注释
      line = line.replace("\t", "")  # 清除TAB
      line = line.replace(" ", "")  # 清除空格
      line = line.replace("\"", "")  # 清除引号
      line = line.replace("'", "")  # 清除引号
      if len(line) < 1:
        continue
      obj = line.split("=")
      if not obj:
        continue
      if obj[0] == key:  # 找到值了，返回
        return obj[1]
  
  return None

# 生成文件指纹树
def calcFileFingerAndCopyHandler(filePath):
  for x in ignoreFiles:
    if x in filePath:
      return

  md5 = calc_md5(filePath)
  key = filePath.replace(TMP_PATH, "")
  assetsTree[key] = [os.path.getsize(filePath), md5]
  copyFile(filePath, RES_DEST_PATH + md5)


# 从 lua 文件中找到对应的配置项
VERSION_NAME = readLuaConfig(BASE_PATH + "src/config.lua", "VERSION_HOST")  # 版本号
GAME_ID = readLuaConfig(BASE_PATH + "src/config.lua", "GAME_ID")  # 游戏ID
BRANCH_ID = readLuaConfig(BASE_PATH + "src/config.lua", "BRANCH_ID")  # 分支ID
SCRIPT_VERSION = readLuaConfig(BASE_PATH + "src/app/const.lua", "SCRIPT_VERSION_ID")
SCRIPT_VERSION = SCRIPT_VERSION or readLuaConfig(BASE_PATH + "src/app/init.lua", "SCRIPT_VERSION_ID")
SCRIPT_VERSION = int(SCRIPT_VERSION)  # 脚本版本号
MAIN_VERSION = VERSION_NAME.split('.')[0]  # 主版本号


# TODO: 修改这里的链接为你的服务端的下载链接
URLS = {
  "r": "http://dl.hotupdate.com/release",
  "t": "http://dl.hotupdate.com/test",
}

if not sys.argv or len(sys.argv) < 2 or sys.argv[1] not in URLS.keys():
  print '用法：', sys.argv[0], URLS.keys()
  sys.exit()

ENV_ID = sys.argv[1]

print "生成热更文件列表"
print "注意：", " 输入的环境ID为：", ENV_ID, " 热更新的根URL为：", URLS.get(ENV_ID)
print
print "版本号: ", VERSION_NAME, " 游戏ID: ", GAME_ID, " 分支ID: ", BRANCH_ID, " 脚本版本ID: ", str(SCRIPT_VERSION)
time.sleep(2)

ignoreFiles = (".DS_Store", "Thumb.db")  # 要忽略的文件
RES_PATH = BASE_PATH + "build/res"  # 要扫描的目录
versionFile = "version.txt"
indexFile = "resindex.txt"
BASE_URL = URLS[ENV_ID]
subPath = GAME_ID + '/v' + MAIN_VERSION + '_' + BRANCH_ID + "/"
url = BASE_URL + '/' + subPath
BUILD_PATH = BASE_PATH + "update_build/" + subPath # 编译路径
RES_DEST_PATH = BUILD_PATH + "resources/"
TMP_PATH = BUILD_PATH + "tmp/"

versionTree = {
  "gameId" : GAME_ID,
  "branchId" : BRANCH_ID,
  "versionURL" : url + versionFile,
  "indexURL" : url + indexFile,
  "downloadURL" : url + 'resources/',
  "mainVersion" : MAIN_VERSION,
  "scriptVersion" : SCRIPT_VERSION,
  "envId" : ENV_ID,
}
assetsTree = {}
rootTree = deepcopy(versionTree)
rootTree['assets'] = assetsTree


removePath(BUILD_PATH)  # 先清空编译目录
os.makedirs(RES_DEST_PATH)
copyPath(RES_PATH, TMP_PATH)  # 拷贝资源目录
removeFile(TMP_PATH + indexFile)  # 删除不需要的索引文件
listPathByHandler(TMP_PATH, calcFileFingerAndCopyHandler)  # 生成所有文件的指纹树


# 写入文件
f2 = open(BUILD_PATH + indexFile, 'w')
f2.write(json.dumps(rootTree))
f2.close()

versionTree['indexSign'] = calc_md5(BUILD_PATH + indexFile)  # 更新project文件的md5，以方便下载后验证
f1 = open(BUILD_PATH + versionFile, 'w')
f1.write(json.dumps(versionTree))
f1.close()

copyFile(BUILD_PATH + indexFile, RES_PATH)  # 为本项目更新索引文件
removePath(TMP_PATH)
