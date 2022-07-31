-- Helper utilities for talking to HTTP endpoints

local M = {}

M.curl = function(method, addr, user, password, body)
    local command = 'curl --silent -X '..method..' -u '..user..':'..password..' --basic "'..addr..'"'

    local result = vim.fn.system(command)

    return vim.json.decode(result)
end

return M;
