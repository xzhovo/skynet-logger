local skynet = require "skynet"
local debug_swith = skynet.getenv("log_debug")

local user_logger_swith = skynet.getenv("my_logger")
local is_daemon = skynet.getenv("daemon") ~= nil

local log = {}

local LOG_LEVEL = {
    DEBUG   = 1,
    INFO    = 2, 
    WARN    = 3, 
    ERROR   = 4, 
    FATAL   = 5
}

local OUT_PUT_LEVEL = LOG_LEVEL.DEBUG

local LOG_LEVEL_DESC = {
    [1] = "debug ",
    [2] = "info  ",
    [3] = "  warn",
    [4] = " error",
    [5] = " fatal",
}

local send_log_fun = function(level, str)
    skynet.error(string.format("%s", str))
end
if user_logger_swith then
    if is_daemon then
        send_log_fun = function(level, str)
            skynet.send(".logger", "lua", "logging", LOG_LEVEL_DESC[level], str)
        end
    else
        send_log_fun = function(level, str)
            print(string.format("[:%08x][%s][%s] %s", skynet.self(), os.date("%H:%M:%S"), LOG_LEVEL_DESC[level], str))
        end
    end
end

local function format(fmt, ...)
    local ok, str = pcall(string.format, fmt, ...)
    if ok then
        return str
    else
        return "error format : " .. fmt
    end
end

local function send_log(level, ...)
    -- if level < OUT_PUT_LEVEL then
    --     return
    -- end

    local str = ""
    local argsNum = select("#", ...)
    if argsNum == 1 then
        str = tostring(...)
    elseif argsNum > 1 then
        local t = {...}
        for i=1, #t do
            str = str .. tostring(t[i])
            if i ~= #t then
                str = str .. " "
            end
        end
        --str = format(...)
    end

    if level >= LOG_LEVEL.WARN then
        local info = debug.getinfo(3)
    	if info then
    		local filename = string.match(info.short_src, "[^/.]+.lua")
    		str = string.format("%s   <%s:%d>", str, filename, info.currentline)
        end
    end
    
    send_log_fun(level, str)
end

function log.separate(path, file, no_change_dir)
    if is_daemon and user_logger_swith then
        skynet.call(".logger", "lua", "separate", path, file, no_change_dir)
    end
end

function log.close()
    if is_daemon and user_logger_swith then
        skynet.call(".logger", "lua", "close")
    end
end

function log.forward(path, file, no_change_dir)
    if is_daemon and user_logger_swith then
        skynet.call(".logger", "lua", "forward", path, file, no_change_dir)
    end
end

function log.debug(fmt, ...)
    if not debug_swith then
        return 
    end
    send_log(LOG_LEVEL.DEBUG, fmt, ...)
end

function log.info(fmt, ...)
    send_log(LOG_LEVEL.INFO, fmt, ...)
end

function log.warning(fmt, ...)
    send_log(LOG_LEVEL.WARN, fmt, ...)
end

function log.error(fmt, ...)
    send_log(LOG_LEVEL.ERROR, fmt, ...)
end

function log.fatal(fmt, ...)
    send_log(LOG_LEVEL.FATAL, fmt, ...)
end

return log
