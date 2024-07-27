--[[
规则名称: 允许特定国家访问

过滤阶段: 请求阶段

危险等级: 低危

规则描述: 允许 cf-ipcountry 字段值为 JP 或者 SG的请求访问网站，其他国家限制访问
--]]

-- 获取请求头中的 cf-ipcountry 字段
local cf_ipcountry = waf.reqHeaders["cf-ipcountry"]

-- 定义允许访问的国家
local allowed_countries = {["JP"] = true, ["SG"] = true}

-- 检查 cf-ipcountry 字段值是否在允许列表中
if cf_ipcountry and allowed_countries[cf_ipcountry] then
    return false -- 允许访问
else
    return true, "限制非指定国家访问", true -- 限制访问
end
