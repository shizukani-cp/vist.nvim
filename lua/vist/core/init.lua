---@class Vist.Item
---@field id string
---@field display? string
---@field icon? string
---@field icon_hl? string
---@field data? any

---@class Vist.Action<T>
---@field kind `T`
---@field data? any

---@class Vist.State
---@field id? string
---@field line string

---@class Vist.Adapter
---@field bufname fun(): string
---@field list fun(): Vist.Item[]
---@field parse? fun(state: Vist.State[]): Vist.Action<any>[]
---@field do_action? fun(action: Vist.Action<string>)
---@field open_item? fun(id: number, line: string)
---@field on_open? fun(bufnr: number)
---@field confirm? fun(actions: Vist.Action<string>[]): boolean

local function parse_line(line)
    local id, rest = line:match("^%s*{(.-)}%s*(.*)$")

    if id then
        local clean_text = rest
        local path_part = rest:match("%s+(.*)$")
        if path_part then
            clean_text = path_part
        end
        return id, clean_text
    else
        local clean_text = line:match("^%s*(.*)$") or line
        return nil, clean_text
    end
end

local M = {}

---@param adapter Vist.Adapter
function M.open(adapter)
    local name = adapter.bufname()
    local items = adapter.list()
    local lines = {}
    for _, item in ipairs(items) do
        local icon = item.icon and (item.icon .. " ") or ""
        local text = string.format("{%s}%s%s", item.id, icon, item.display or tostring(item.id))
        table.insert(lines, "  " .. text)
    end

    local old_buf = vim.fn.bufnr(name)
    if old_buf ~= -1 then
        vim.api.nvim_buf_delete(old_buf, { force = true })
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].modified = false
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].bufhidden = "hide"
    vim.api.nvim_set_option_value("conceallevel", 2, { scope = "local", win = 0 })
    vim.cmd([[syntax match VistId /^\s*{.*}/ conceal]])
    vim.wo.conceallevel = 2
    vim.api.nvim_set_option_value("concealcursor", "nvc", { scope = "local", win = 0 })
    local ns_id = vim.api.nvim_create_namespace("vist_icons")
    for i, item in ipairs(items) do
        if item.icon then
            local row = i - 1
            local id_part = string.format("{%s}", item.id)
            local start_col = 2 + #id_part

            vim.api.nvim_buf_set_extmark(buf, ns_id, row, start_col, {
                end_col = start_col + #item.icon,
                hl_group = item.icon_hl or "None",
            })
        end
    end

    local group = vim.api.nvim_create_augroup("VistGroup_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        group = group,
        callback = function()
            local current_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            local state = {}

            for _, line in ipairs(current_lines) do
                local id, clean_text = parse_line(line)
                table.insert(state, { id = id, text = clean_text })
            end

            local has_parse, actions = pcall(adapter.parse, state)
            if not has_parse then
                actions = {}
            end
            local success, result = pcall(adapter.confirm, actions)
            if not success then
                result = true
            end
            if not result then
                return
            end
            for _, action in ipairs(actions) do
                local _, _ = pcall(adapter.do_action, action)
            end
            vim.bo[buf].modified = false
            M.open(adapter)
        end,
    })
    vim.keymap.set("n", "<CR>", function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]

        local id, clean_text = parse_line(line)
        if id then
            local _, _ = pcall(adapter.open_item, id, clean_text)
        end
    end, { buffer = buf, silent = true, noremap = true })
    local _, _ = pcall(adapter.on_open, buf)
end

return M
