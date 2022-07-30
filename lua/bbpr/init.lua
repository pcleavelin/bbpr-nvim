-- A simple interface for viewing pull requests in a BitBucket repository

local api = vim.api
local buf, win, pr_list = nil

local function get_pr_list()
    pr_list = {
        ["PR-1"] = {
            ["link"] = "http://google.com"
        },
        ["PR-2"]= { ["link"] = "http://google.com" },
        ["PR-3"] = { ["link"] = "http://google.com" }
    }
end

local function open_window()
    -- create a new scratch buffer
    buf = api.nvim_create_buf(false, true)

    -- set buffer to delete when hidden
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'swapfile', false)
    api.nvim_buf_set_option(buf, 'filetype', 'pat-bbpr')

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

    win = api.nvim_open_win(buf, true, opts)
end

local function close()
    if win and api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
    end
end

local function open_pr()
    -- split by spaces and grab the first element
    local path = api.nvim_get_current_line():gmatch("%S+")()

    local pr = pr_list[path]
    
    print(pr)
end

local function paint()
    api.nvim_buf_set_option(buf, 'modifiable', true)

    local list = {}
    for k,v in pairs(pr_list) do
        table.insert(list, #list + 1, k..' <=> '..v["link"])
    end

    api.nvim_buf_set_lines(buf, 0, -1, false, list)

    api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function set_mappings()
    local mappings = {
        q = 'close()',
        ['<cr>'] = 'open_pr()'
    }

    for k,v in pairs(mappings) do
        api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"bbpr".'..v..'<cr>',
            {
                nowait = true,
                noremap = true,
                silent = true
            })
    end
end

local function bbpr()
    if win and api.nvim_win_is_valid(win) then
        api.nvim_set_current_win(win)
    else
        open_window()
    end

    get_pr_list()
    set_mappings()
    paint()
end

return {
    bbpr = bbpr,
    open_window = open_window,
    close = close,
    open_pr = open_pr,
}
