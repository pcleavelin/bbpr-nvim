-- A simple interface for viewing pull requests in a BitBucket repository
local bb = require('bbpr.bitbucket')

local api = vim.api
local pr_list, pr = nil
local workspace, repo = nil

local desc_buf, file_list_buf, diff_buf, diff_buf_2 = nil
local pr_desc_win, pr_diff_win = nil

-- Taken from https://gist.github.com/GabrielBdeC/b055af60707115cbc954b0751d87ec23
function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from, true)
    while delim_from do
        if (delim_from ~= 1) then
            table.insert(result, string.sub(self, from, delim_from-1))
        end
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from, true)
    end
    if (from <= #self) then table.insert(result, string.sub(self, from)) end
    return result
end

local function set_mappings(buf, mappings)
    for k,v in pairs(mappings) do
        api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"bbpr".'..v..'<cr>',
            {
                nowait = true,
                noremap = true,
                silent = true
            })
    end
end

local function set_buf_options(buf, mappings)
    -- set buffer to delete when hidden
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'swapfile', false)
    api.nvim_buf_set_option(buf, 'filetype', 'pat-bbpr')
    api.nvim_buf_set_option(buf, 'modifiable', false)

    if mappings ~= nil then
        set_mappings(buf, mappings)
    end
end

local function create_split_win(opts)
    if vertical then
        api.nvim_command(opts)
    else
        vim.cmd(opts)
    end

    local win = api.nvim_get_current_win()
    local buf = api.nvim_get_current_buf()

    set_buf_options(buf)
    -- api.nvim_win_set_buf(win, buf)

    return win, buf
end

local function close()
    if diff_buf and api.nvim_buf_is_valid(diff_buf) then
        api.nvim_command("tabclose")
    end
end

local function paint_file_list_buf(source_commit, dest_commit)
    api.nvim_buf_set_option(file_list_buf, 'modifiable', true)

    local result = vim.cmd('silent exec ":r !git diff '..dest_commit..'..'..source_commit..' --name-only"');

    api.nvim_buf_set_option(file_list_buf, 'modifiable', false)
end

local function paint_desc()
    api.nvim_buf_set_option(desc_buf, 'modifiable', true)

    local list = pr["desc"]:split("\n")

    api.nvim_buf_set_lines(desc_buf, 0, -1, false, list)

    api.nvim_buf_set_option(desc_buf, 'modifiable', false)
    api.nvim_buf_set_option(desc_buf, 'syntax', 'markdown')
end

local function open_pr(line)
    -- split by spaces and grab the first element
    local pr_index = line:split(':')[1]
    pr = pr_list[pr_index]

    close()

    pr['files'] = bb.get_comments(pr['id'], workspace, repo)

    api.nvim_command("tabnew")

    -- setup window showing the file diff
    pr_diff_win = api.nvim_get_current_win()
    diff_buf = api.nvim_get_current_buf()
    set_buf_options(diff_buf)
    api.nvim_win_set_buf(pr_diff_win, diff_buf)

    -- setup file chooser
    pr_file_list_win, file_list_buf = create_split_win("botright vnew")
    api.nvim_win_set_option(pr_file_list_win, 'cursorline', true)

    set_mappings(file_list_buf, {
        q = 'close()',
        ['<cr>'] = 'load_diff("'..pr['source_commit']..'", "'..pr['dest_commit']..'")'
    })
    paint_file_list_buf(pr['source_commit'], pr['dest_commit'])

    -- setup window showing PR description
    pr_desc_win, desc_buf = create_split_win("new")
    set_buf_options(desc_buf)
    paint_desc()

    api.nvim_set_current_win(pr_file_list_win)
end

local function create_win_from_buf(_buf, winopts)
    local win = -1
    local buf = _buf

    -- check if the buffer is still alive
    if buf and api.nvim_buf_is_valid(buf) then
        win = vim.fn.bufwinnr(buf)
    else
        -- if not re-create
        buf = api.nvim_create_buf(false, true)
        set_buf_options(buf)
    end

    -- check if the diff window still alive
    if win == -1 then
        -- create new window to the left and attach buffer
        vim.cmd(winopts)
        win = api.nvim_get_current_win()
        api.nvim_set_current_win(win)

        api.nvim_win_set_buf(win, buf)
    else
        -- if it still exists and the buffer is attached, switch to that window
        vim.cmd("exec "..win..".." .. "'wincmd w'")
    end 
    
    return win, buf
end

local function add_code_comment(buf, ns, line, col, author, comment)
    api.nvim_buf_set_extmark(buf, ns, line, col, { virt_lines = { { {author..': ', { 'Bold', 'Italic' }}}, {{comment, { 'Bold', 'Italic' }} } } })
end

local function load_diff(source_commit, dest_commit)
    local file = api.nvim_get_current_line()
    local win, win_2

    win_2, diff_buf = create_win_from_buf(diff_buf, 'topleft vnew')
    api.nvim_buf_set_option(diff_buf, 'modifiable', true)
    api.nvim_buf_set_lines(diff_buf, 0, -1, false, {})

    api.nvim_buf_set_name(diff_buf, 'Merging into: '..dest_commit..' - '..file)
    vim.cmd('silent exec ":r !git show '..dest_commit..':./'..file..'"');
    vim.cmd('diffthis')

    api.nvim_buf_set_option(diff_buf, 'modifiable', false)

    win, diff_buf_2 = create_win_from_buf(diff_buf_2, 'new')
    api.nvim_buf_set_option(diff_buf_2, 'modifiable', true)
    api.nvim_buf_set_lines(diff_buf_2, 0, -1, false, {})

    api.nvim_buf_set_name(diff_buf_2, 'Taking from: '..source_commit..' - '..file);
    vim.cmd('silent exec ":r !git show '..source_commit..':./'..file..'"');
    vim.cmd('diffthis')

    api.nvim_buf_set_option(diff_buf_2, 'modifiable', false)

    local ns_id = api.nvim_create_namespace('bbpr_diff')
    api.nvim_buf_clear_namespace(diff_buf_2, ns_id, 0, -1)

    if pr['files'] then
        for k,comments in pairs(pr['files']) do 
            if k == file then
                for _,comment in pairs(comments) do
                    add_code_comment(diff_buf_2, ns_id, comment['line'], 0, comment['author'], comment['contents'])
                    for _,reply in ipairs(comment['replies']) do
                        add_code_comment(diff_buf_2, ns_id, comment['line'], 0, reply['author'], reply['contents'])
                    end
                end
           end
        end
    end
end

local function bbpr()
    workspace, repo = bb.get_local_workspace_and_repo()
    pr_list = bb.get_pull_requests(workspace, repo)

    local pr_title_list = {}
    local i = 1
    for k,v in pairs(pr_list) do
        pr_title_list[i] = k..":"..v['title']
        i = i+1
    end

    local pickers = require "telescope.pickers"
    local finders = require "telescope.finders"
    local conf = require("telescope.config").values
    local opts = require("telescope.themes").get_dropdown{}

    local actions = require "telescope.actions"
    local action_state = require "telescope.actions.state"

    pickers.new(opts, {
        prompt_title = "Pull Requests",
        finder = finders.new_table {
            results = pr_title_list
        },
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                --print(vim.inspect(selection))
                --vim.api.nvim_put({ selection[1] }, "", false, true)
                open_pr(selection[1])
            end)

            return true
        end
    }):find()

    -- vim.fn['fzf#vim#grep']('echo "'..pr_string:sub(1,-2)..'"', 1, { ['options'] = { '--ansi' }, ['sink'] = open_pr }, 0)
end

bbpr()

return {
    bbpr = bbpr,
    close = close,
    open_pr = open_pr,
    load_diff = load_diff
}
