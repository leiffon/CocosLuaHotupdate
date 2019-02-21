--
--                       _oo0oo_
--                      o8888888o
--                      88" . "88
--                      (| -_- |)
--                      0\  =  /0
--                    ___/`---'\___
--                  .' \\|     |-- '.
--                 / \\|||  :  |||-- \
--                / _||||| -:- |||||- \
--               |   | \\\  -  --/ |   |
--               | \_|  ''\---/''  |_/ |
--               \  .-\__  '-'  ___/-. /
--             ___'. .'  /--.--\  `. .'___
--          ."" '<  `.___\_<|>_/___.' >' "".
--         | | :  `- \`.;`\ _ /`;.`/ - ` : | |
--         \  \ `_.   \_ __\ /__ _/   .-` /  /
--     =====`-.____`.___ \_____/___.-`___.-'=====
--                       `=---='
--
--
--     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
--               佛祖保佑         永无BUG
--
--
--

function __G__TRACKBACK__(errorMessage)
    print("----------------------------------------")
    local output = "LUA ERROR: " .. tostring(errorMessage) .. "\n"
    output = output .. debug.traceback("", 2) .. "\n"
    print(output)
    print("----------------------------------------")
    -- pcall(function () postError(tostring(output)) end)
end

-- 设置内存管理
collectgarbage("collect")               -- 收集垃圾，释放所有不可到达对象
collectgarbage("setpause", 1000)        -- 执行完一轮至启动下一轮收集的等待时间
collectgarbage("setstepmul", 50000)     -- 收集器的工作速度

cc.FileUtils:getInstance():addSearchPath("res")
package.path = package.path .. ";src/"
cc.FileUtils:getInstance():setPopupNotify(false)

require("config")

local target = cc.Application:getInstance():getTargetPlatform()
if target == 0 or target == 2 then
    require("app.MyApp").new():run()
    return
end

-- 以上兼容 Win or Mac 平台模拟器，以下为移动设备下的配置

DATA_PATH = cc.FileUtils:getInstance():getWritablePath() .. ".data/" -- 写入文件目录
UPDATE_PATH = DATA_PATH .. ".loader/"  -- 热更新工作目录
GAME_ENTRANCE = "app.MyApp"  -- APP入口，在热更新完成后会被require

JIT_BIT = ""
if jit then
    local target = cc.Application:getInstance():getTargetPlatform()
    if target == 0 or target == 1 or target == 2 or target == 3 then
        JIT_BIT = "32"
    elseif string.find(jit.arch, "64") ~= nil then
        JIT_BIT = "64"
    else
        JIT_BIT = "32"
    end
end

PRE_LOAD_ZIPS = {  -- 进游戏所需要预加载的ZIP列表
    "framework" .. JIT_BIT .. ".zip",
    "game" .. JIT_BIT .. ".zip"
}

local bit = JIT_BIT == "64" and "32" or "64"
UPDATE_IGNORE = { -- 根据手机位数跳过更新的文件列表
    "init32.zip", "init64.zip", 
    "updater" .. bit .. ".zip", "preupdate" .. bit .. ".zip",
    "framework" .. bit .. ".zip", "game" .. bit ..".zip"
}


-- run directly.
if DEBUG > 0 then
    for _,v in ipairs(PRE_LOAD_ZIPS) do
        cc.LuaLoadChunksFromZIP(v)
    end
    require(GAME_ENTRANCE).new():run()
    return
end

-- run with hot update check.
local configs = {
    app_entrance = GAME_ENTRANCE,   -- 游戏入口，更新完成后需要调用
    work_path = UPDATE_PATH,        -- 更新模块的工作目录
    preload_zips = PRE_LOAD_ZIPS,   -- 需要加载的代码zip文件列表
    design_width = CONFIG_SCREEN_WIDTH,    -- 设计宽
    design_height = CONFIG_SCREEN_HEIGHT,  -- 设计高
    seconds = 60,                   -- 超时时间
    slient_size = 8 * 1024 * 1024,  -- 静默下载数据网络下的提示大小

    zip64 = JIT_BIT,  -- 64还是32位的信息
    ignore_list = UPDATE_IGNORE     -- 跳过更新的文件列表
}
cc.FileUtils:getInstance():addSearchPath(UPDATE_PATH, true)
cc.LuaLoadChunksFromZIP("updater" .. JIT_BIT .. ".zip")
require("Updater").new(configs):run()
