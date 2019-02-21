local MainScene = class("MainScene", function()
    return display.newScene("MainScene")
end)

function MainScene:ctor()
    display.newSprite("update/scene.png"):addTo(self):pos(display.cx, display.cy)
end


function MainScene:onEnterTransitionFinish()
    require "lfs"
    local function __rmdir(path)
        local iter, dir_obj = lfs.dir(path)
        while true do
            local dir = iter(dir_obj)
            if dir == nil then break end
            if dir ~= "." and dir ~= ".." then
                local curDir = path .. dir
                local mode = lfs.attributes(curDir, "mode")
                if mode == "directory" then
                    __rmdir(curDir .. "/")
                elseif mode == "file" then
                    os.remove(curDir)
                end
            end
        end
        local succ, des = os.remove(path)
        printLog("remove", des)
        return succ
    end

    local function onButtonClicked(event)
        dump(event)
        if event.buttonIndex == 1 then
        	device.openURL("新包下载地址")
        end
        if io.exists(UPDATE_PATH) then
            __rmdir(UPDATE_PATH)
        end
        os.exit()
    end
    device.showAlert("更新提示", "必须更新才能继续游戏", {"朕知道了"}, onButtonClicked)
end

function MainScene:onExitTransitionStart()
end

function MainScene:onExit()
end

function MainScene:onCleanup()
    collectgarbage("collect")
end

return MainScene
