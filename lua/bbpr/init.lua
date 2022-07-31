-- A simple interface for viewing pull requests in a BitBucket repository
local bb = require('bbpr.bitbucket')

local api = vim.api
local pr_list, pr = nil

local choose_buf, desc_buf, file_list_buf, diff_buf, diff_buf_2 = nil
local pr_choose_win, pr_desc_win, pr_diff_win = nil

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

local function get_pr_list()
    pr_list = {
        ["PR-1"] = {
            ["link"] = "http://google.com"
        },
        ["PR-2"]= { ["link"] = "http://google.com" },
        ["PR-3"] = { ["link"] = "http://google.com" }
    }
end

local function get_pr(link)
    pr = {
        ["desc"] = "This is a test description for a test Pull Request from Bitbucket.\nThough this is not actually from bitbucket.",
        ["branch"] = "master",
    }
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

local function open_pr_choose_window()
    -- create a new scratch buffer
    choose_buf = api.nvim_create_buf(false, true)
    set_buf_options(choose_buf, {
        q = 'close()',
        ['<cr>'] = 'open_pr()'
    })


    local width = api.nvim_get_option("columns")
    local height = api.nvim_get_option("lines")

    local win_height = math.ceil(height * 0.9)
    local win_width = math.ceil(width * 0.8)

    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local opts = {
        style = "minimal",
        border = "single",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col
    }

    pr_choose_win = api.nvim_open_win(choose_buf, true, opts)
    api.nvim_win_set_option(pr_choose_win, 'cursorline', true)
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

local function close(win)
    if pr_choose_window and api.nvim_win_is_valid(pr_choose_window) then
        api.nvim_win_close(pr_choose_window, true)
    end

    if win and api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
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
end

local function paint_choose_buf()
    if pr_list == nil then
        return
    end

    api.nvim_buf_set_option(choose_buf, 'modifiable', true)

    local list = {}
    for k,v in pairs(pr_list) do
        table.insert(list, #list + 1, k..' <=> '..v['title'])
    end

    api.nvim_buf_set_lines(choose_buf, 0, -1, false, list)

    api.nvim_buf_set_option(choose_buf, 'modifiable', false)
end

local function open_pr()
    -- split by spaces and grab the first element
    local pr_index = api.nvim_get_current_line():gmatch("%S+")()
    pr = pr_list[pr_index]

    close(pr_choose_win)
    pr_choose_win = nil
    choose_buf = nil

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
end

local function bbpr()
    if win and api.nvim_win_is_valid(pr_choose_win) then
        api.nvim_set_current_win(pr_choose_win)
    else
        open_pr_choose_window()
    end

    local workspace, repo = bb.get_local_workspace_and_repo()
    pr_list = bb.get_pull_requests(workspace, repo)
    paint_choose_buf()
end

return {
    bbpr = bbpr,
    close = close,
    open_pr = open_pr,
    load_diff = load_diff
}
