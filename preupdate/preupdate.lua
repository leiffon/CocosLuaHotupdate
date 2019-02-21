--
-- Author: xx
-- Date: 2018-05-27 12:44:06
--


local preupdate = {}

preupdate.__cname = "preupdate"
preupdate.__index = preupdate
preupdate.__ctype = 2

local sharedDirector = cc.Director:getInstance()
local device = require("loader.device")
local display = require("loader.display")
local utils = require("loader.utils")

function preupdate.new(...)
    local instance = setmetatable({}, preupdate)
    instance.class = preupdate
    instance:ctor(...)
    return instance
end


function preupdate:ctor(scene, update)
    self.scene = scene
    self.oncomplete = update or function() end
end

function preupdate:run()
    if device.platform ~= "ios" then
        self:launchimage()
    else
        self:playOpening()
    end
end

function preupdate:launchimage()
    local img = cc.Sprite:create("update/launch.png")
    if not img then
        return self:playOpening()
    end
    self.scene:addChild(img)
    img:setPosition(display.cx, display.cy)
    local seq = cc.Sequence:create(
        cc.DelayTime:create(0.7),
        cc.FadeOut:create(0.4),
        cc.CallFunc:create(function()
            img:removeFromParent()
            self:playOpening()
        end
    ))
    img:runAction(seq)
end

function preupdate:playOpening()
    local bool, utils = true, cc.FileUtils:getInstance()
    for _, ext in ipairs {"json", "atlas", "png"} do
        bool = bool and utils:isFileExist("update/opening."..ext)
    end
    if not bool then
        return self:update()
    end
    local bg = cc.LayerColor:create{ r = 255, g = 255, b = 255, a = 255 }
    self.scene:addChild(bg)
    local sk = sp.SkeletonAnimation:create("update/opening.json", "update/opening.atlas")
    self.scene:addChild(sk)
    sk:setPosition(display.cx, display.cy)
    sk:registerSpineEventHandler(function()
        sk:runAction(cc.Sequence:create(
            cc.DelayTime:create(0.01),
            cc.CallFunc:create(function()
                sk:removeFromParent()
                bg:removeFromParent()
                self:update()
            end)
        )) 
    end, 2)
    sk:setAnimation(0, "animation", false)
end

function preupdate:update()
    utils.logFile("preupdate.update:Here to adjust UpdateScene's UI")
    local scene = self.scene
    local RES = {
        scene = "img/scene/login.png",
        progress_bg = "update/update_progress_bg.png",
        progress = "update/update_progress.png"
    }
    scene.init(RES)

    -- scene._setProgress = self:setprogress(scene)
    -- scene.txtfmt = "loading... %s％"
    -- scene.bg:setTexture("scene/launch.png")
    -- scene.text:setPosition(display.cx, display.bottom + 250)
    -- scene.progress:setPosition(display.cx, display.bottom + 10)
    -- scene.progress_bg:setPosition(display.cx, display.bottom + 300)
    self.oncomplete()
end

-- function preupdate:setprogress(scene)
--     return function(...)

--     end
-- end

return preupdate