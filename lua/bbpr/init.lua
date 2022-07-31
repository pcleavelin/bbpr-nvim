-- A simple interface for viewing pull requests in a BitBucket repository

local api = vim.api
local pr_list, pr = nil

local choose_buf, desc_buf, file_list_buf, diff_buf = nil
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

local function create_split_win(vertical)
    if vertical then
        api.nvim_command("botright vnew")
    else
        vim.cmd("new")
    end

    local win = api.nvim_get_current_win()
    local buf = api.nvim_create_buf(false, true)

    set_buf_options(buf)
    api.nvim_win_set_buf(win, buf)

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

local function paint_file_list_buf()
    api.nvim_buf_set_option(file_list_buf, 'modifiable', true)

    local result = vim.cmd('silent exec ":r !git diff HEAD~1 --name-only"');

    api.nvim_buf_set_option(file_list_buf, 'modifiable', false)
end

local function paint_desc()
    api.nvim_buf_set_option(desc_buf, 'modifiable', true)

    local list = pr["desc"]:split("\n")

    api.nvim_buf_set_lines(desc_buf, 0, -1, false, list)

    api.nvim_buf_set_option(desc_buf, 'modifiable', false)
end

local function paint_choose_buf()
    api.nvim_buf_set_option(choose_buf, 'modifiable', true)

    local list = {}
    for k,v in pairs(pr_list) do
        table.insert(list, #list + 1, k..' <=> '..v["link"])
    end

    api.nvim_buf_set_lines(choose_buf, 0, -1, false, list)

    api.nvim_buf_set_option(choose_buf, 'modifiable', false)
end

local function open_pr()
    -- split by spaces and grab the first element
    local pr_index = api.nvim_get_current_line():gmatch("%S+")()
    local pr = pr_list[pr_index]
    get_pr(pr["link"])

    close(pr_choose_win)
    pr_choose_win = nil
    choose_buf = nil

    api.nvim_command("tabnew")

    -- setup window showing the file diff
    pr_diff_win = api.nvim_get_current_win()
    diff_buf = api.nvim_create_buf(false, true)
    set_buf_options(diff_buf)
    api.nvim_win_set_buf(pr_diff_win, diff_buf)

    -- setup file chooser
    pr_file_list_win, file_list_buf = create_split_win(true)
    --api.nvim_win_set_option(pr_file_list_win, 'cursorline', true)

    set_mappings(file_list_buf, {
        ['<cr>'] = 'load_diff()'
    })
    paint_file_list_buf()

    -- setup window showing PR description
    pr_desc_win, desc_buf = create_split_win(false)
    set_buf_options(desc_buf)
    paint_desc()

    api.nvim_set_current_win(pr_file_list_win)

    print("diff: "..api.nvim_win_get_number(pr_diff_win)..", list: "..api.nvim_win_get_number(pr_file_list_win)..", desc: "..api.nvim_win_get_number(pr_desc_win))
end

local function load_diff()
    local file = api.nvim_get_current_line()
    local win = -1

    -- TODO: change these two `if`s into a function to grab windows
    -- check if the diff buffer is still alive
    if diff_buf and api.nvim_buf_is_valid(diff_buf) then
        win = vim.fn.bufwinnr(diff_buf)
    else
        -- if not re-create
        diff_buf = api.nvim_create_buf(false, true)
        set_buf_options(diff_buf)
    end

    -- check if the diff window still alive
    if win == -1 then
        -- create new window to the left and attach buffer
        vim.cmd("topleft vnew")
        win = api.nvim_get_current_win()
        api.nvim_set_current_win(win)

        api.nvim_win_set_buf(win, diff_buf)
    else
        -- if it still exists and the buffer is attached, switch to that window
        vim.cmd("exec "..win..".." .. "'wincmd w'")
    end 

    api.nvim_buf_set_option(diff_buf, 'modifiable', true)
    api.nvim_buf_set_lines(diff_buf, 0, -1, false, {})

    -- TODO: use commit from PR instead of `HEAD~1`
    vim.cmd('silent exec ":r !git show HEAD~1:./'..file..'"');
    vim.cmd('diffthis')

    api.nvim_command("vnew")
    vim.cmd('silent exec ":r !git show master:./'..file..'"');
    vim.cmd('diffthis')

    api.nvim_buf_set_option(diff_buf, 'modifiable', false)
end

local function bbpr()
    if win and api.nvim_win_is_valid(pr_choose_win) then
        api.nvim_set_current_win(pr_choose_win)
    else
        open_pr_choose_window()
    end

    get_pr_list()
    paint_choose_buf()
end

return {
    bbpr = bbpr,
    open_pr_choose_window = open_pr_choose_window,
    close = close,
    open_pr = open_pr,
    load_diff = load_diff
}
