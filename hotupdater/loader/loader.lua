local json = require("loader.json")
local http = require("loader.http")
local crypto = require("loader.crypto")
local device = require("loader.device")
local network = require("loader.network")
local scheduler = require("loader.scheduler")
local utils = require("loader.utils")

local checkint = utils.checkint
local writeFile = utils.writeFile
local removeFile = utils.removeFile
local renameFile = utils.renameFile
local rmdir = utils.rmdir
local readFile = utils.readFile
local copyFile = utils.copyFile
local mkdir = utils.mkdir
local loadJsonFile = utils.loadJsonFile
local tableCount = utils.tableCount
local readResFile = utils.readResFile

--------------------------------- CONFIG START -------------------------------
-- 下载版本文件，对比检查，下载资源索引文件，检验索引文件，
-- 分析需要下载的文件，下载并检验文件，替换当前版本，更新结束。
local STATES = {
    init = 'init',
    start = "start",
    downVersion = "downVersion",
    downVersionEnd = "downVersionEnd",
    downIndex = "downIndex",
    downIndexEnd = "downIndexEnd",
    downFiles = "downFiles",
    downFilesEnd = "downFilesEnd",
    isEnd = "end",
}

local EVENTS = {
    success = 'success',
    fail = 'fail',
    progress = 'progress',
    state = 'state',
}

local SUCCESS_TYPES = {
    noNewVersion = 'noNewVersion',
    updateSuccess = 'updateSuccess',
}

local ERRORS = {
    rawIndexReadFail = 'rawIndexReadFail',
    createFile = "errorCreateFile",
    network = "errorNetwork",
    unknown = "errorUnknown";
}

local versionInfoNew = {}  -- 新下载的版本信息
local indexInfoCurr = {}  -- 当前版的文件索引信息，可参考resindex.txt文件
local indexInfoRaw = {}  -- 原包里面的索引信息
local indexInfoNew = {}  -- 新下载的索引文件的信息

--[[
名词说明：
原版：指APK或IPA包中自带的文件
当前版：指更新目录中的经过检验的文件
新版：指最新下载的，还未完成更新的文件，新版经过验证后会变成当前版
]]
local CURRENT_SUFFIX = ".curr"  -- 当前启用版本所用的后缀
local NEW_SUFFIX = ".new"  -- 正在更新中的版本的后缀，如果此类文件存在，说明上一次的更新未完成
local VERSION_FILE_NAME = "version.txt"  -- 其实是json，这里只是为了防止运营商劫持所修改的后缀
local INDEX_FILE_NAME = "resindex.txt"  -- 其实是json，这里只是为了防止运营商劫持所修改的后缀
local UPDATE_PACKAGE_INDEX = "updater%s.zip"  -- 更新包的索引名称, 这里是为了能更新自身而放在这里的
local DOWNLOAD_THREADS = 4  -- 同时下载的任务数
local DOWNLOAD_SCHEDULER = nil  -- 下载的定时器
--------------------------------- CONFIG END ---------------------------------


local loader = {}

loader.state_ = nil
loader.downloadStates_ = {}
loader.startTime_ = 0

-- 当前有效的索引文件
function loader.indexFileOfCurr()
    return updater.work_path .. INDEX_FILE_NAME .. CURRENT_SUFFIX
end

-- 新版的工程索引文件
function loader.indexFileOfNew()
    return updater.work_path .. INDEX_FILE_NAME .. NEW_SUFFIX
end

function loader.init(zip64)
    utils.logFile('loader.init', zip64)
    local str64 = zip64 or ""
    loader.downloadList_ = nil
    UPDATE_PACKAGE_INDEX = string.format(UPDATE_PACKAGE_INDEX, zip64)
    if nil ~= loader.state_ then
        utils.logFile('loader.init fail with nil state')
        return
    end
    utils.logFile(updater.work_path)

    local ok, err = mkdir(updater.work_path, true)
    utils.logFile("mkdir", ok, err)
    
    loader.setState_(STATES.init)
    loader.loadRawIndex_()
    loader.loadCurrIndex_()
end

function loader.loadRawIndex_()
    utils.logFile("loader.loadRawIndex_()", INDEX_FILE_NAME)
    local content = json.decode(readResFile(INDEX_FILE_NAME))
    if not content then
        utils.logFile("error: ", ERRORS.rawIndexReadFail)
        return
    end
    indexInfoRaw = content
    return true
end

function loader.loadCurrIndex_()
    utils.logFile("loader.loadCurrIndex_()", loader.indexFileOfCurr())
    local content = loadJsonFile(loader.indexFileOfCurr())
    if not content then
        return
    end
    indexInfoCurr = content
    local currV = checkint(indexInfoCurr.scriptVersion)
    local rawV = checkint(indexInfoRaw.scriptVersion)
    if rawV >= currV then
        indexInfoCurr = {}
        removeFile(loader.indexFileOfCurr())
        utils.logFile("loader.loadCurrIndex_() rawV >= currV")
    end
    if indexInfoCurr.scriptVersion then  -- 立即启用当前目录，以便更新进度的场景UpdateScene也能使用新资源
        cc.FileUtils:getInstance():addSearchPath(loader.getCurrPath_(), true)
    end
    return true
end

function loader.setState_(state)
    utils.logFile("loader.setState_", state)
    assert(state)
    loader.state_ = state
    loader.onState_(state)
end

function loader.getVersionURL_()
    utils.logFile("loader.getVersionURL_()")
    if indexInfoCurr and indexInfoCurr.versionURL then
        return indexInfoCurr.versionURL
    end
    if indexInfoRaw and indexInfoRaw.versionURL then
        return indexInfoRaw.versionURL
    end
end

function loader.checkNetwork_(handler)
    utils.logFile("loader.checkNetwork_")
    if network.isInternetConnectionAvailable() then
        return true
    end
    utils.logFile("before device.showAlert")
    device.showAlert("网络错误", "当前无可用的网络连接，请检查后再重试！", {"重试"}, function()
        scheduler.performWithDelayGlobal(function() loader.update(handler) end, 0.1)
    end)
    return false
end

function loader.setLoadEventHandler(handler)
    utils.logFile("loader.setLoadEventHandler(handler)")
    assert(handler)
    loader.updateHandler_ = handler
end

function loader.update()
    utils.logFile("loader.update()")
    if not loader.checkNetwork_(loader.updateHandler_) then
        utils.logFile("if not loader.checkNetwork_(handler) then")
        return
    end
    if loader.state_ ~= STATES.init and loader.state_ ~= STATES.isEnd then
        return
    end
    loader.startTime_ = os.time()
    loader.startCheckScheduler_()
    loader.downloadStates_ = {}

    loader.setState_(STATES.start)

    if not device.isAndroid and not device.isIOS then
        return loader.endWithEvent_(EVENTS.fail, "LOADER NOT SUPPORT THIS PLATFORM.")
    end
    if not indexInfoCurr.scriptVersion and not indexInfoRaw.scriptVersion then
        return loader.endWithEvent_(EVENTS.fail, 'No version Info or not init!')
    end

    removeFile(loader.indexFileOfNew())

    loader.setState_(STATES.downVersion)
    -- loader.onProgress_(0)
    loader.downVersion_()
end

function loader.endWithEvent_(event, ...)
    utils.logFile("loader.endWithEvent_", event, ...)
    loader.onProgress_(100)
    if indexInfoCurr and indexInfoCurr.scriptVersion then  -- 启用目录
        cc.FileUtils:getInstance():addSearchPath(loader.getCurrPath_(), true)
    end
    loader.stopCheckScheduler_()
    loader.setState_(STATES.isEnd)
    loader.updateHandler_(EVENTS[event], ...)
end

function loader.onSuccess_(sucType)
    utils.logFile("loader.onSuccess_: ", sucType)
    loader.endWithEvent_(EVENTS.success, sucType)
end

function loader.onFail_(message)
    utils.logFile("loader.onFail_: ", message)
    loader.updateHandler_(EVENTS.fail, message)
end

function loader.onProgress_(percent, ...)
    utils.logFile("loader.onProgress_: ", percent)
    loader.updateHandler_(EVENTS.progress, percent, ...)
end

function loader.onState_(state, ...)
    utils.logFile("loader.onState_: ", state)
    if loader.updateHandler_ then
        loader.updateHandler_(EVENTS.state, state, ...)
    end
end

function loader.clean()
    utils.logFile("loader.clean")
    loader.stopCheckScheduler_()
    loader.state_ = nil
    indexInfoCurr = {}
    indexInfoRaw = {}
    indexInfoNew = {}
    loader.downloadStates_ = {}
end

-- 下载version.txt文件
function loader.downVersion_(url)
    utils.logFile("loader.downVersion_()", url)
    assert(loader.state_ == STATES.downVersion)
    local url = (url or loader.getVersionURL_()) .. '?' .. os.time()
    utils.logFile("down url: ", url)
    if not url then
        return loader.endWithEvent_(EVENTS.fail, 'get Version URL fail')
    end
    
    local function failFunc()
        utils.logFile("download version fail")
        loader.setState_(STATES.downVersionEnd)
        return loader.endWithEvent_(EVENTS.fail, 'download version fail')
    end
    
    local function sucFunc(data)
        utils.logFile("download version file success.")
        if not data or string.len(data) < 2 then
            failFunc()
            return
        end
        loader.setState_(STATES.downVersionEnd)
        local result = json.decode(data)
        if not result or not result.scriptVersion or not result.mainVersion then
            return loader.endWithEvent_(EVENTS.fail, 'decode version file fail')
        end

        versionInfoNew = result
        loader.checkVersionNumber_(result)
    end

    http.get(url, sucFunc, failFunc)
end

local function isNew__(newV, compV)
    return checkint(newV) > checkint(compV)
end

function loader.checkVersionNumber_(result)
    utils.logFile("loader.checkVersionNumber_")
    local newV = result.scriptVersion
    local currV = indexInfoCurr.scriptVersion
    local rawV = indexInfoRaw.scriptVersion
    utils.logFile("check version: ", "new:"..tostring(newV), "cur:"..tostring(currV), "raw:"..tostring(rawV))

    if result.mainVersion ~= indexInfoRaw.mainVersion then  -- 大版本不一致，直接返回
        utils.logFile("mainVersion not equal ", tostring(result.mainVersion), tostring(indexInfoRaw.mainVersion))
        return loader.endWithEvent_(EVENTS.fail, 'MAIN VERSION IS NOT EQUAL!')
    end

    if result.gameId ~= indexInfoRaw.gameId or 
        result.branchId ~= indexInfoRaw.branchId then
        utils.logFile("params check fail ")
        return loader.endWithEvent_(EVENTS.fail, 'PARAMS CHECK FAIL!')
    end

    if currV then
        if isNew__(newV, currV) then
            utils.logFile("goto downloadIndexFile_ by currV")
            loader.downloadIndexFile_(result)
            return
        end
    elseif isNew__(newV, rawV) then
        utils.logFile("goto downloadIndexFile_ by rawV")
        loader.downloadIndexFile_(result)
        return
    end

    return loader.onSuccess_(SUCCESS_TYPES.noNewVersion)
end

function loader.downloadIndexFile_(result)
    utils.logFile("loader.downloadIndexFile_(result)")
    assert(loader.state_ == STATES.downVersionEnd)
    loader.setState_(STATES.downIndex)
    local function failFunc()
        utils.logFile("download index fail")
        loader.setState_(STATES.downIndexEnd)
        return loader.endWithEvent_(EVENTS.fail, 'download index file fail')
    end
    local function sucFunc(file)
        utils.logFile("download index suc", file)
        loader.setState_(STATES.downIndexEnd)
        if crypto.md5file(file) ~= result.indexSign then
            return loader.endWithEvent_(EVENTS.fail, 'check new index file sign fail')
        end

        local data = readFile(file)
        local indexNew = json.decode(data)
        if not indexNew or not indexNew.scriptVersion then
            return loader.endWithEvent_(EVENTS.fail, 'decode new index file fail')
        end

        indexInfoNew = indexNew
        loader.setState_(STATES.downIndexEnd)
        loader.downloadFiles_()
    end
    utils.logFile("before download index: ", loader.indexFileOfNew(), result.indexURL)
    http.download(result.indexURL .. '?' .. os.time(), loader.indexFileOfNew(), sucFunc, failFunc)
end

function loader.getNewPath_()
    return updater.work_path .. versionInfoNew.scriptVersion .. '/'
end

function loader.getCurrPath_()
    if not indexInfoCurr.scriptVersion then
        return updater.work_path .. indexInfoRaw.scriptVersion .. '/'
    end
    return updater.work_path .. indexInfoCurr.scriptVersion .. '/'
end

function loader.filterIgnore_(workList)
    for _, key in pairs(updater.ignore_list or {}) do
        workList[key] = nil
    end
end

-- 比对给定的列表与本地文件
-- 如果本地文件存在，且文件的MD5值相等，则跳过对应文件
-- 反之将错误的本地文件删除，并放进列表
function loader.filterFilesByPathAndList_(newPath, workList)
    local list = {}
    for k,v in pairs(workList) do
        local filename = newPath .. k
        if not utils.exists(filename) then
            list[k] = v
        elseif crypto.md5file(filename) ~= v[2] then
            removeFile(filename)
            list[k] = v
        end
    end
    return list
end

-- 去除可直接从当前版中（本地）复制的项
-- 先统计需要复制的文件数量
-- 再开定时器复制，以防止阻塞主线程
-- 计算md5时也会有一定程度的阻塞，如果不能忍受也可用下方注释掉的方法(开启定时器，代价是时间变长)
function loader.filterLastVersionFiles_(workList, currPath, newPath)
    local list, copylist, total, copied = {}, {}, 0, 0
    for k,v in pairs(workList) do
        local curr = currPath .. k
        if not utils.exists(curr) or crypto.md5file(curr) ~= v[2] then
            list[k] = v
        else
            copylist[k] = v
            total = total + 1
        end
    end
    utils.logFile("copy files: ", total)
    if total == 0 then
        loader.start2download_(list)
        return
    end

    loader.onState_("copystart")
    local k, v, s
    s = scheduler.scheduleGlobal(function()
        k, v = next(copylist, k)
        local from = currPath .. k
        local to = newPath .. k
        local pinfo = utils.pathinfo(to)
        mkdir(pinfo.dirname, true)
        if not copyFile(from, to) then  -- 复制失败，加入列表
            list[k] = v
        elseif crypto.md5file(to) ~= v[2] then  -- 文件签名不正确，加入列表
            list[k] = v
            removeFile(to)
        end
        copied = copied + 1
        loader.onState_("copyfiles", math.ceil(copied/total*100), copied, total)
        if copied == total then
            scheduler.unscheduleGlobal(s)
            loader.start2download_(list)
        end
    end, 0.01)
end

-- function loader.filterLastVersionFiles_(workList, currPath, newPath)
--     local list, copylist, copytotal, checked, checktotal = {}, {}, 0, 0, 0
--     for k, v in pairs(workList) do
--         checktotal = checktotal + 1
--     end
--     print("start checking", checktotal, os.time())
--     local k, v, s
--     s = scheduler.scheduleUpdateGlobal(function()
--         k, v = next(workList, k)
--         print("checking md5: ", k, os.clock())
--         local curr = currPath .. k
--         if not utils.exists(curr) or crypto.md5file(curr) ~= v[2] then
--             list[k] = v
--         else
--             copylist[k] = v
--             copytotal = copytotal + 1
--         end
--         checked = checked + 1
--         if checked == checktotal then
--             scheduler.unscheduleGlobal(s)
--             print("check complete:", os.time())
--             loader.copyfiles(list, copylist, copytotal, currPath, newPath)
--         end
--     end)
-- end

-- function loader.copyfiles(list, copylist, total, currPath, newPath)
--     utils.logFile("copy files: ", total)
--     if total == 0 then
--         loader.start2download_(list)
--         return
--     end
--     loader.onState_("copystart")
--     local copied, k, v, s = 0
--     s = scheduler.scheduleGlobal(function()
--         k, v = next(copylist, k)
--         local from = currPath .. k
--         local to = newPath .. k
--         local pinfo = utils.pathinfo(to)
--         mkdir(pinfo.dirname, true)
--         if not copyFile(from, to) then  -- 复制失败，加入列表
--             list[k] = v
--         elseif crypto.md5file(to) ~= v[2] then  -- 文件签名不正确，加入列表
--             list[k] = v
--             removeFile(to)
--         end
--         copied = copied + 1
--         loader.onState_("copyfiles", math.ceil(copied/total*100), copied, total)
--         if copied == total then
--             scheduler.unscheduleGlobal(s)
--             loader.start2download_(list)
--         end
--     end, 0.01)
-- end

function loader.start2download_(downList_)
    downList_ = loader.filterProjectFiles_(downList_) -- 去除原版中已存在且相同的项
    loader.onState_("checkComplete")

    utils.logFile("calc downlist: ", downList_)
    
    loader.downloadList_ = downList_ -- 值不为nil后，checkUpdateProgress_()开始下载
    
    loader.downloadedSize_ = 0
    loader.totalSize_, loader.totalCount_ = loader.calcSizeAndCount_(downList_)
    loader.onProgress_(loader.calcDownloadProgress_())
end

function loader.filterProjectFiles_(workList)
    if not workList then
        return {}
    end

    local list = {}
    for k,v in pairs(workList) do
        if not loader.inProject_(k, v) then
            list[k] = v
        end
    end
    return list
end

-- 判断给定的元素是否在项目包中已存在
function loader.inProject_(key, item)
    if not key or not item or not indexInfoRaw then
        return false
    end
    if not indexInfoRaw.assets or not indexInfoRaw.assets[key] then
        return false
    end
    return indexInfoRaw.assets[key][2] == item[2]
end

function loader.downloadFiles_()
    utils.logFile("loader.downloadFiles_()")
    assert(loader.state_ == STATES.downIndexEnd)
    loader.setState_(STATES.downFiles)

    local currPath = loader.getCurrPath_()
    local newPath = loader.getNewPath_()
    mkdir(newPath)  -- 创建新版的文件夹

    local downList_ = indexInfoNew.assets
    loader.filterIgnore_(downList_) -- 去除不需要更新的黑名单文件
    -- utils.logFile("full assets: ", downList_) -- 打印所有资源文件列表(调试用，文件数很多时耗性能)
    downList_ = loader.filterFilesByPathAndList_(newPath, downList_) -- 去除已下载成功的项
    downList_ = loader.filterLastVersionFiles_(downList_, currPath, newPath) -- 去除从当前版中复制成功的项
    -- downList_ = loader.filterProjectFiles_(downList_) -- 去除原版中已存在且相同的项
    -- utils.logFile("calc downlist: ", downList_)
    
    -- loader.downloadList_ = downList_
    
    -- loader.downloadedSize_ = 0
    -- loader.totalSize_, loader.totalCount_ = loader.calcSizeAndCount_(downList_)
    -- loader.onProgress_(loader.calcDownloadProgress_())
end

function loader.calcDownloadProgress_()
    if loader.totalSize_ <= 0 then
        return 100
    end
    local downloaded, total = loader.downloadedSize_, loader.totalSize_
    return math.ceil((downloaded / total) * 100), downloaded, total
end

function loader.calcSizeAndCount_(list)
    utils.logFile("loader.calcSizeAndCount_(list)")
    local size, count = 0, 0
    for k,v in pairs(list) do
        size = size + v[1]
        count = count + 1
    end
    utils.logFile(size, count)
    return size, count
end

function loader.startCheckScheduler_()
    utils.logFile("loader.startCheckScheduler_()")
    if not DOWNLOAD_SCHEDULER then
        DOWNLOAD_SCHEDULER = scheduler.scheduleGlobal(loader.checkUpdateProgress_, 0.1)
    end
end

function loader.stopCheckScheduler_()
    utils.logFile("loader.stopCheckScheduler_()")
    if DOWNLOAD_SCHEDULER then
        scheduler.unscheduleGlobal(DOWNLOAD_SCHEDULER)
        DOWNLOAD_SCHEDULER = nil
    end
end

function loader.incrDownloadedSize_(size)
    loader.downloadedSize_ = loader.downloadedSize_ + size
end

function loader.getResURL_(sign)
    return versionInfoNew.downloadURL .. sign
end

function loader.downloadResFile_(filePath, fileMetaData)
    utils.logFile("loader.downloadResFile_", filePath)
    assert(filePath and fileMetaData)
    local fileTotalSize, fileMD5 = fileMetaData[1], fileMetaData[2]
    
    local function failFunc()
        utils.logFile("download res fail!", filePath)
        loader.downloadStates_[filePath] = 0
        DOWNLOAD_THREADS = DOWNLOAD_THREADS + 1
    end
    
    local lastDownSize = 0
    local function sucFunc(file)
        utils.logFile("download resfile suc: ", filePath)
        DOWNLOAD_THREADS = DOWNLOAD_THREADS + 1
        if crypto.md5file(file) ~= fileMD5 then  -- 下载的文件MD5不正确
            loader.downloadStates_[filePath] = 0
            return
        end

        loader.downloadStates_[filePath] = 2
        loader.incrDownloadedSize_(fileTotalSize - lastDownSize)  -- 累加下载大小
        loader.onProgress_(loader.calcDownloadProgress_())  -- 通知总下载进度
    end
    
    local function progressFunc(total, dltotal)
        if not DOWNLOAD_SCHEDULER then
            return
        end
        if total > 0 then
            fileTotalSize = total
        end
        if dltotal > 0 then
            loader.incrDownloadedSize_(dltotal - lastDownSize)  -- 累加下载大小
            lastDownSize = dltotal
            loader.onProgress_(loader.calcDownloadProgress_())  -- 通知总下载进度
        end
    end

    local url = loader.getResURL_(fileMD5)
    local seconds = math.max(10, fileTotalSize / (10 * 1024))  -- 动态指定下载的超时时间，因为文件大小差异太大
    local filename = loader.getNewPath_() .. filePath
    local pinfo = utils.pathinfo(filename)
    mkdir(pinfo.dirname, true)
    loader.downloadStates_[filePath] = 1
    http.download(url, filename, sucFunc, failFunc, seconds, progressFunc)
end

-- 启用新版本的索引文件和版本文件
function loader.overWriteCurrFiles_()
    utils.logFile("loader.overWriteCurrFiles_()")
    if writeFile(loader.indexFileOfCurr(), readFile(loader.indexFileOfNew())) then
        utils.logFile("overWriteCurrFiles_ success")
        local path = loader.getCurrPath_()
        if utils.exists(path) then
            utils.logFile("delpath: ", path)
            rmdir(path)
        end
        return true
    end

    return false
end

-- 检测 updater%d.zip 是否在更新列表中，在的话复制到updater.work_path根目录下
-- 下次才会启用新的updater%d.zip
function loader.checkSelf()
    local data = loader.downloadList_[UPDATE_PACKAGE_INDEX]
    if data then
        local from = loader.getNewPath_() .. UPDATE_PACKAGE_INDEX
        local target = updater.work_path .. UPDATE_PACKAGE_INDEX
        local to = target .. "_temp"
        if copyFile(from, to) then
            if crypto.md5file(to) ~= data[2] then
                removeFile(to)  -- 复制后文件签名不正确，则删除
            else
                if utils.exists(target) then
                    removeFile(target)
                end
                renameFile(to, target)
                utils.logFile("loader.checkSelf", "update self success!")
            end
        end
    end
end

function loader.onDownloadFinish_(desc)
    utils.logFile("loader.onDownloadFinish_", desc, loader.downloadStates_)
    loader.setState_(STATES.downFilesEnd)
    if loader.isFinish_() then  -- 下载完成且没有失败的
        loader.overWriteCurrFiles_()
        indexInfoCurr = indexInfoNew
        loader.checkSelf()
        return loader.onSuccess_(SUCCESS_TYPES.updateSuccess)
    else
        return loader.endWithEvent_(EVENTS.fail, desc)
    end
end

function loader.isFinish_()
    if not loader.downloadList_ then
        return false
    end
    if tableCount(loader.downloadList_) ~= tableCount(loader.downloadStates_) then
        return false
    end
    for k,v in pairs(loader.downloadStates_) do
        if v ~= 2 then
            return false
        end
    end
    return true
end

function loader.checkUpdateProgress_()
    if os.time() - loader.startTime_ > (updater.seconds or 5 * 60) then
        return loader.onDownloadFinish_("timeout")
    end
    if loader.isFinish_() then
        return loader.onDownloadFinish_("isall finish")
    end
    if not loader.downloadList_ then
        return
    end

    for k,v in pairs(loader.downloadList_) do  -- 0 未开始 1 下载中 2 已下载
        if DOWNLOAD_THREADS <= 0 then
            break
        end
        local status = loader.downloadStates_[k]
        if status == nil then
            loader.downloadStates_[k] = 0
            status = 0
        end
        if status == 0 then
            DOWNLOAD_THREADS = DOWNLOAD_THREADS - 1
            loader.downloadResFile_(k, v)
        end
    end
end

return loader
