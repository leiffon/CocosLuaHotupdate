# quick-cocos2d-lua 热更新模块代码+配套脚本工具

3.0 更新日志：

LoadScene更名为UpdateScene

更新文件大小提示(downloaded/total)

更新前预执行额外的lua代码preupdate/preupdate.lua, 可单独更新preupdate以避免更新整个updater模块

实现updater模块自我更新

更新时的背景和进度条资源路径不再写入src/config.lua内，而直接写死在loader/UpdateScene.lua，有变更需求时只需更新updater模块即可或者在preupdate.lua中直接对UpdateScene作调整修改（推荐后者）

本项目从[基于 quick-cocos2d-x 3.3 的热更新小项目](https://github.com/uhoohei/jw_loader)修改而来，感谢！

## 要点：
0. 基于[Quick-Cocos2dx-Community](https://github.com/u0u0/Quick-Cocos2dx-Community)3.6.5版本，不适用于3.7+; Mac平台下运行;
1. 无需对引擎进行改造，小巧简洁，无需强后台支持，很多热更新方案中都需要比较强的后端接口配合，此方案只需要将静态文件上传至WEB服务器即可，不需要动态语言后台的支持
2. 项目无需特别的结构调整，将src/main.lua、src/config.lua、src/app/const.lua 按需配置后替换进工程，同时放入热更所需背景和进度条等资源到res/update文件夹即可
3. 将src源码目录加密分包（init*.zip, updater*.zip, framework64*.zip, game*.zip）。init*.zip由cpp自动加载，其他由lua加载。game*.zip为游戏主逻辑（app文件夹）
4. 自动判断手机cpu位数，避免下载无用的.zip
5. 热更模块基于引擎基础模块编写，更新过程在一个独立的scene中完成，不与项目本身代码混合
6. 热更中程序退出，再次启动会自动判断已下载的文件，节省流量
7. 支持多文件同时下载


## 使用步骤：
0、配置好src/main.lua、src/config.lua、src/app/const.lua中的热更的关键参数并准备好热更所需资源文件夹res/update后，将游戏工程的src和res拷贝至此热更目录，并按如下步骤依次运行脚本1，2，3

1、updater_build.sh 可选参数：游戏工程路径（默认为该脚本所在位置）

用途：编译热更新模块“hotupdater文件夹+preupdate文件夹”的lua代码为updater32.zip和updater64.zip，并放到游戏工程的res/下（秉承开源精神，纯打包不加密）

注意：

loader/UpdateScene场景，实现进度条功能，请提前将所需资源放入update文件夹并按需命名

单个ZIP包，检测和下载更新文件所需的lua库均已内置，不与项目本身代码产生耦合；

现在这个升级模块本身也可以被更新（为updater**.zip单独设置一个固定的搜索目录，有更新时就更新到该固定目录），不过如果不是迫不得已不推荐这么做，显示上的问题尽量通过更新preupdate实现！


2、framework_build.sh 可选参数：游戏工程路径（默认为该脚本所在位置）

用途：编译quick引擎的 cocos 和 framework 目录为一整个res/framework32.zip和res/framework64.zip（秉承开源精神，纯打包不加密）

注意：是通过 cocos 和 framework 放入某个临时目录后再进行打包的方式


3、game_build.sh r|t(正式｜测试环境标识 为必须参数)

用途：编译加密游戏代码和资源，生成打包文件和热更文件

步骤：

1）、编译并加密src源码（游戏主逻辑）为game32.zip和game64.zip后放入.data目录内 （别忘设置签名-es和密码-ek，需与Classes/AppDelegate.cpp中的签名密码保持一致）

2）、调用init_build.sh编译并加密（App中最先被执行的lua代码）为init32.zip和init64.zip，放入.data目录

3）、创建build目录（用于发布应用包）

4）、python encrypt_res.py 加密res/下的图片资源并放入（包括之前放入的updater*.zip和framework*.zip）build/res目录

5）、复制所有.data目录下的.zip文件到build/res下

6）、python make_update_files.py $1 生成最终的热更新文件夹（以src/main.lua里的GAME_ID命名）放入update_build下

注意：

将src下的文件夹（app文件夹等）拷贝到临时目录打包的方式以屏蔽冗余文件一起打包进game

t测试表示生成更新文件先内部测试是否正常，确认一切正常后再以r方式运行将文件release

存放热更新文件的服务器URL在make_update_files.py内设置


3.1、init_build.sh （别忘设置签名-es和密码-ek）

用途：
编译并加密lua初始化文件src根目录下的lua文件(主要是main.lua、config.lua)为init32.zip和init64.zip，放入.data目录

注意：通过将src根目录下的lua文件拷贝至.data/src目录下再打包的方式

3.2、encrypt_res.py 必须参数： 加密签名-es和密码-ek

用途：将资源加密后放入build/res目录

注意：可设置不要加密的文件list

3.3、make_update_files.py 必须参数 r|t(正式｜测试环境标识)

用途：
生成检测热更文件所需要的索引文件，同时在目录update_build下生成所有热更MD5形式的文件

步骤：

1）计算build/res目录下所有加密后的文件的指纹(md5)，同时将资源拷贝至update_build/resources/根目录下并以它自己的md5重命名

2）将所有资源文件以 “名称:[大小，md5]” 的格式写入索引文件update_build/resindex.txt（并拷贝一份到build/res下）

3）将版本信息VERSION_NAME GAME_ID BRANCH_ID SCRIPT_VERSION等写入update_build/version.txt（包括resindex.txt的md5）

注意：
实际生产环境下可能会受到运营商网络限制，安卓手机使用数据流量方式访问网络时，从阿里云上下载version.txt总是要耗时20s，可通过将热更新服务器的URL设置CDN加速的方式解决这个问题

## 热更的关键参数说明

### 游戏ID，不同的游戏以此作为区别
文件：src/config.lua
变量名：GAME_ID
被 make_update_files.py 所读取

### 主版本号
文件：src/config.lua
变量名：VERSION_HOST
自定义主版本号（只取第一位整数，可与Android和iOS打包编译的主版本号对应定义），它同时也需要被 make_update_files.py 所读取，热更时会判断此值，一般大版本号只有在项目依赖的游戏引擎或项目原生代码层（OC,java，接入第三方SDK）变更时才变更

### 分支ID
文件：src/config.lua
变量名：BRANCH_ID 字符串
分支ID的定义和作用是为了区别不同的第三方平台或SDK，有时候为了发布某些渠道，可能要接入他们的SDK，这样的话他们的代码与主分支可能稍有不同，此时为了区别更新，引入了分支ID的概念

### 脚本版本ID
文件：src/app/const.lua 或者 src/app/init.lua
变量名：SCRIPT_VERSION_ID 整数
脚本版本ID是唯一用来比较判断是否有新版本的变量，当线上版本大于本地版本时，才有后续的热更流程，
***每一次发布热更版本都必须改变此值并用热更的打包脚本进行编译***

### 跨主版本更新
文件：src/app/mainVersionUpdate.lua
跨主版本更新参考代码，将其放在游戏入口处，作为新版更新代码推送给用户，提醒用户下载新版本。


### UPDATE_PATH
文件：src/main.lua
更新的工作路径

### GAME_ENTRANCE
文件：src/main.lua
游戏的真正入口，热更完成后会加载此入口文件并new出来进行真正的进入游戏的过程


### 热更背景及进度条资源路径
文件：loader/UpdateScene.lua
资源路径在RES表中指定（拷贝已下载文件进度条路径在COPY中指定），统一放在从工程目录res/update目录下，也可通过热更新替换（不过要下次生效）

注意：所有资源非必须，最低配置为scene.png,update_progress_bg.png，update_progress.png

## 热更的流程
一般framework_build.sh与updater_build.sh在没有新的变更的时候不需要每次都编译。
游戏发布后，平时热更只需执行工程根目录下的 game_build.sh [r|t], 将所生成的 update_build 目录下以GAME_ID命名的文件夹传到热更新服务器(通常工程文件会比较多传输需要时间，最好先上传到临时目录后再一次移动到指定目录）

## 修改工程入口以支持加密加载
修改工程文件 Classes/AppDelegate.cpp，我的3.6.5是从93行开始，以支持资源和代码的加密
**请修改下列SET_YOUR_PWD为你的真实项目密码**
当然你也可以不修改，那样你需要去掉所有脚本中的与加密相关的配置选项
```c++
    FileUtils::getInstance()->setResourceEncryptKeyAndSign("SET_YOUR_PWD", "YOUR_SIGN");
#if 1
    // use luajit bytecode package
    stack->setXXTEAKeyAndSign("SET_YOUR_PWD", "YOUR_SIGN");
    
#ifdef CC_TARGET_OS_IPHONE
    if (sizeof(long) == 4) {
        stack->loadChunksFromZIP("res/init32.zip");
    } else {
        stack->loadChunksFromZIP("res/init64.zip");
    }
#else
    // android, mac, win32, etc
    stack->loadChunksFromZIP("res/init32.zip");
#endif
    stack->executeString("require 'main'");
#else // #if 0
    // use discrete files
    engine->executeScriptFile("src/main.lua");
#endif
```
