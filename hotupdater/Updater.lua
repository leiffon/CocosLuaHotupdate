-- 更新包所包含的所有模块，方便移除
local updatePackage = {
    "Updater",
    "loader.utils",
    "loader.http",
    "loader.json",
    "loader.network",
    "loader.display",
    "loader.crypto",
    "loader.scheduler",
    "loader.device",
    "loader.loader",
    "loader.LoadScene",
    "loader.luaoc",
    "loader.luaj",
}

local Updater = {}

Updater.__cname = "Updater"
Updater.__index = Updater
Updater.__ctype = 2

local sharedDirector = cc.Director:getInstance()
local loader = require("loader.loader")
local utils = require("loader.utils")
local selfName = "updater"  -- 更新模块的全局名称，要修改的话得修改关联的地方

function Updater.new(...)
    local instance = setmetatable({}, Updater)
    instance.class = Updater
    instance:ctor(...)
    return instance
end

function Updater:ctor(configs)
    utils.removeLogFile()
    utils.logFile("Updater:ctor", configs)
    assert(configs.preload_zips)
    assert(configs.app_entrance)
    assert(configs.work_path)
    assert(configs.design_width)
    assert(configs.design_height)
    assert(configs.seconds)
    utils.logFile("assert finish")
    _G[selfName] = self
    self.configs_ = configs
    self.preload_zips = configs.preload_zips
    self.app_entrance = configs.app_entrance
    self.work_path = configs.work_path
    self.design_width = configs.design_width
    self.design_height = configs.design_height
    self.seconds = math.max(120, configs.seconds)
    
    self.zip64 = configs.zip64
    self.ignore_list = configs.ignore_list
    utils.logFile("set configs finish.")
end

function Updater:run()
    utils.logFile("Updater:run()")
    loader.init(self.zip64)
    local scene = require("loader.UpdateScene")
    self:enterScene(scene)
end

function Updater:enterScene(__scene)
    if sharedDirector:getRunningScene() then
        sharedDirector:replaceScene(__scene)
    else
        sharedDirector:runWithScene(__scene)
    end
end

return Updater
