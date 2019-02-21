local loader = require("loader.loader")
local display = require("loader.display")
local utils = require("loader.utils")

local scene = cc.Scene:create()
scene.name = "UpdateScene"

local COPY = {
    progress_bg = "update/copy_progress_bg.png",
    progress = "update/copy_progress.png"
}
local RES = {
    checking = "update/checking", --spine骨骼动画，非必须
    scene = "update/scene.png",
    progress_bg = "update/update_progress_bg.png",
    progress = "update/update_progress.png"
}
local OLD = {
    scene = "scene/login.png",
    progress_bg = "scene/update_progress_bg.png",
    progress = "scene/update_progress.png"
}

function scene.init(res)
    res = type(res) == "table" and res or RES
    local bg = cc.Sprite:create(res.scene or RES.scene)
    bg = bg or cc.Sprite:create(OLD.scene)
    if bg then
        -- if CONFIG_SCREEN_AUTOSCALE == "FIXED_HEIGHT" then
        --     bg:setScale(display.width / updater.design_width)
        -- elseif CONFIG_SCREEN_AUTOSCALE == "FIXED_WIDTH" then
        --     bg:setScale(display.height / updater.design_height)
        -- end
        display.align(bg, display.CENTER, display.cx, display.cy)
        scene:addChild(bg, 0)
    end

    scene._labelDebug = cc.Label:createWithSystemFont("", "Arial", 27)
    -- scene._labelDebug:setColor(display.c3b(50, 50, 50))
    display.align(scene._labelDebug, display.CENTER, display.cx, display.bottom + 44)
    scene:addChild(scene._labelDebug, 10)

    scene.txtfmt = "载入中... %s％"
    scene.copytxtfmt = "正在检查更新 %s％"
    local text = cc.Label:createWithSystemFont("", "Arial", 32)
    display.align(text, display.CENTER, display.cx, display.bottom + 146)
    scene:addChild(text, 11)

    scene.bg = bg
    scene.text = text
    scene.checking = scene.createchecking(res.checking)
    scene.copy, scene.copy_bg = scene.createprogress(COPY)
    scene.progress, scene.progress_bg = scene.createprogress(res)
    scene.onprogress = function() end -- 可在preupdate中重定义进度监听事件


    scene.onLoaderEvent("debug label")
    -- scene.onLoaderEvent("progress", 44)
    loader.setLoadEventHandler(scene.onLoaderEvent)
end

function scene.createchecking(filename)
    filename = filename or RES.checking
    local bool, utils = true, cc.FileUtils:getInstance()
    for _, ext in ipairs {".json", ".atlas", ".png"} do
        bool = bool and utils:isFileExist(filename..ext)
    end
    if bool then
        local sk = sp.SkeletonAnimation:create(filename..".json", filename..".atlas")
        scene:addChild(sk)
        sk:setVisible(false)
        sk:setPosition(display.cx, display.cy)
        return sk
    end
end

function scene.removechecking()
    if not scene.checking then return end
    scene.checking:removeFromParent()
    scene.checking = nil
end

function scene.createprogress(res)
    local x, y = display.cx, display.bottom + 130
    local progress_bg = cc.Sprite:create(res.progress_bg or RES.progress_bg)
    progress_bg = progress_bg or cc.Sprite:create(OLD.progress_bg)
    if progress_bg then
        progress_bg:setPosition(x, y)
        progress_bg:setVisible(false)
        scene:addChild(progress_bg, 9)
    end

    local progress_fg = cc.Sprite:create(res.progress or RES.progress)
    progress_fg = progress_fg or cc.Sprite:create(OLD.progress)
    local progress = cc.ProgressTimer:create(progress_fg)
    progress:setType(1)
    progress:setMidpoint({x=0, y=0.5})
    progress:setBarChangeRate({x=1, y=0})
    progress:setPosition(x, y)
    progress:setVisible(false)
    scene:addChild(progress, 10)
    return progress, progress_bg or progress
end

function scene.onLoaderEvent(event, ...)
    utils.logFile("scene.onLoaderEvent", event)
    local vars = {...}
    local str = table.concat(vars, ", ")
    if DEBUG and DEBUG > 0 then
        str = event .. "@" .. str
        scene._labelDebug:setString(str)
    end

    if event == 'fail' then
        scene._labelDebug:setString(str)
    end
    if event == "success" or event == "fail" then
        scene.removechecking()
        scene._setProgress(100)
        scene.enterGameApp()
    elseif event == "state" then
        local state = vars[1]
        if state == "copystart" then
            scene.copy:setVisible(true)
            scene.copy_bg:setVisible(true)
        elseif state == "copyfiles" then
            scene._setCopyProgress(unpack(vars, 2))
        elseif state == "checkComplete" then
            scene.removechecking()
            scene.copy:setVisible(false)
            scene.copy_bg:setVisible(false)
            scene.progress_bg:setVisible(true)
            scene.progress:setVisible(true)
        end
    elseif event == 'progress' and scene._setProgress then
        scene._setProgress(unpack(vars))
    end
end

function scene._setCopyProgress(percent, copied, total)
    scene.copy:setPercentage(percent)
    local str = string.format(scene.copytxtfmt, tostring(percent))
    if copied then
        str = str .. string.format("(%s/%s)", copied, total)
    end
    scene.text:setString(str)
    scene.onprogress("copy", percent, copied, total)
end

function scene._setProgress(percent, downloaded, total)
    scene.progress:setPercentage(percent)
    local str = string.format(scene.txtfmt, tostring(percent))
    if downloaded then
        downloaded = scene.convert(downloaded)
        total = scene.convert(total)
        str = str .. string.format("(%s/%s)", downloaded, total)
    end
    scene.text:setString(str)
    scene.onprogress("download", percent, downloaded, total)
end

local UNIT = {"B", "KB", "MB", "GB"}
function scene.convert(size)
    local i = 1
    while size > 1024 do
        size = size/1024
        i = i+1
    end
    return string.format("%.1f"..UNIT[i], size)
end

function scene.enterGameApp()
    utils.logFile("scene.enterGameApp()")
    for i,v in ipairs(updater.preload_zips) do
        cc.LuaLoadChunksFromZIP(v)
    end
    require(updater.app_entrance).new():run()
end

function scene.startUpdating()
    utils.logFile("scene.startUpdating")
    if scene.checking then
        scene.checking:setVisible(true)
        scene.checking:setAnimation(0, "animation", true)
    end
    loader.update()
end

function scene.onEnter()
    local zip = JIT_BIT and "preupdate" .. JIT_BIT .. ".zip" or ""
    if cc.FileUtils:getInstance():isFileExist(zip) then
        cc.LuaLoadChunksFromZIP(zip)
        require("preupdate").new(scene, scene.startUpdating):run()
    else
        scene.init()
        scene.startUpdating()
    end
end

function scene.onExit()
    utils.logFile("scene.onExit()")
    loader.clean()
    scene:unregisterScriptHandler()
end

function scene.onCleanup()
end

function scene._sceneHandler(event)
    utils.logFile("scene._sceneHandler(event)", event)
    if event == "enter" then
        scene.onEnter()
    elseif event == "cleanup" then
        scene.onCleanup()
    elseif event == "exit" then
        scene.onExit()
    end
end

scene:registerScriptHandler(scene._sceneHandler)

return scene
