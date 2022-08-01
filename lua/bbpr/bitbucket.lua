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

local function collect_comment(v, responses, replies)
    local comment = {}

    comment['id'] = v['id']
    comment['author'] = v['user']['nickname']
    comment['contents'] = v['content']['raw']

    if v['inline'] and type(v['inline']['to']) == 'number' then
        comment['line'] = v['inline']['to']
    elseif v['inline'] and type(v['inline']['from']) == 'number' then
        comment['line'] = v['inline']['from']
    else
        comment['line'] = 1
    end

    for _,response in ipairs(responses) do
        for k,v in pairs(response) do
            if k == "values" then
                for child_key,child in ipairs(v) do
                    if child['parent'] and child['parent']['id'] and child['parent']['id'] == comment['id'] then
                        local child_comment, replies = collect_comment(child, responses, replies)
                        table.insert(replies, #replies+1, child_comment)

                        -- return new comment and recursively modified replies
                        return comment, replies
                    end
                end
            end
        end
    end

    -- return new comment and UN-modified replies
    return comment, replies
end

M.get_comments = function(pr_id, workspace, repo)
    local response = http.curl('GET',
        'https://api.bitbucket.org/2.0/repositories/'..workspace..'/'..repo..'/pullrequests/'..pr_id..'/comments',
        vim.g.bbpr_bb_user,
        vim.g.bbpr_bb_password
    )

    local responses = {}
    table.insert(responses, response)

    while true do
        if response['next'] then
            response = http.curl('GET',
                response['next'], 
                vim.g.bbpr_bb_user,
                vim.g.bbpr_bb_password
            )
            table.insert(responses, response)
        else
            break
        end
    end

    local files = {}
    for _,response in ipairs(responses) do
        for k,v in pairs(response) do
            if k == "values" then
                for _,bb_comment in ipairs(v) do
                    if bb_comment['inline'] and not bb_comment['parent'] then
                        local file_name = bb_comment['inline']['path']
                        if not files[file_name] then
                            files[file_name] = {}
                        end
                        local comment, replies = collect_comment(bb_comment, responses, {})
                        comment['replies'] = replies

                        files[file_name][comment['id']] = comment
                    end
                end
            end
        end
    end


    return files
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
        'https://api.bitbucket.org/2.0/repositories/'..workspace..'/'..repo..'/pullrequests',
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
