-- Helpers to get pull request information from BitBucket

local http = require('bbpr.http')
local M = {}

M.get_local_workspace_and_repo = function ()
    local remote_url = vim.fn.system("git remote get-url origin") 

    local git_path = remote_url:split(':')[2]

    local workspace_repo = git_path:split('/')
    local repo = workspace_repo[2]:split('.')[1]

    return workspace_repo[1], repo
end

local function get_workspaces()
    local response = http.curl('GET',
        'https://api.bitbucket.org/2.0/user/permissions/workspaces',
        vim.g.bbpr_bb_user,
        vim.g.bbpr_bb_password
    )

    local workspaces = {}

    for k,v in pairs(response) do
        if k == "values" then
            for k,v in pairs(v) do
                if v['workspace']['slug'] then
                    table.insert(workspaces, #workspaces + 1, v['workspace']['slug'])
                end
            end
        end
    end

    return workspaces
end

M.get_pull_requests = function(workspace, repo)
    local response = http.curl('GET',
        'https://api.bitbucket.org/2.0/repositories/'..workspace..'/'..repo..'/pullrequests?state=OPEN',
        vim.g.bbpr_bb_user,
        vim.g.bbpr_bb_password
    )

    local prs = {}

    for k,v in pairs(response) do
        if k == "values" then
            for k,v in pairs(v) do
                local pr = {}

                pr['id'] = v['id']
                pr['title'] = v['title']
                pr['desc'] = v['description']
                pr['source_commit'] = v['source']['commit']['hash']
                pr['dest_commit'] = v['destination']['commit']['hash']

                prs[''..pr['id']] = pr
            end
        end
    end

    return prs
end

return M
