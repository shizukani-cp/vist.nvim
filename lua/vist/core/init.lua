---@class Vist.Item
---@field id number
---@field display? string
---@field icon? string
---@field icon_hl? string
---@field data? any

---@class Vist.Action<T>
---@field kind `T`
---@field data? any

---@class Vist.State
---@field id? number
---@field line string

---@class Vist.Adapter
---@field bufname fun(): string
---@field list fun(): Vist.Item[]
---@field parse? fun(state: Vist.State[]): Vist.Action<any>[]
---@field do_action? fun(action: Vist.Action<string>)
---@field open_item? fun(id: number, line: string)
---@field on_open? fun(bufnr: number)
---@field confirm? fun(actions: Vist.Action<string>[]): boolean

local M = {}

---@param adapter Vist.Adapter
function M.open(adapter)
    local name = adapter.bufname()
    local items = adapter.list()
    local lines = {}
    for _, item in ipairs(items) do
        local text = item.display or tostring(item.id) or ""
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

    local ns_id = vim.api.nvim_create_namespace("vist")
    for i, item in ipairs(items) do
        local row = i - 1
        local opts = {
            id = item.id,
            invalidate = true,
        }

        if item.icon then
            opts.virt_text = { { item.icon .. " ", item.icon_hl or "None" } }
            opts.virt_text_pos = "overlay"
        end

        vim.api.nvim_buf_set_extmark(buf, ns_id, row, 0, opts)
    end

    local group = vim.api.nvim_create_augroup("VistGroup_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        group = group,
        callback = function()
            local ns = vim.api.nvim_create_namespace("vist")
            local current_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            local state = {}

            for i, line in ipairs(current_lines) do
                local marks = vim.api.nvim_buf_get_extmarks(0, ns, { i - 1, 0 }, { i - 1, -1 }, {})
                local id = nil
                if #marks > 0 then
                    id = marks[#marks][1]
                end
                local clean_text = line:match("^%s%s(.*)$") or line
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
        line = line:gsub("^  ", "")
        local ns = vim.api.nvim_create_namespace("vist")
        local marks = vim.api.nvim_buf_get_extmarks(0, ns, { row, 0 }, { row, -1 }, {})

        if #marks > 0 then
            local id = marks[#marks][1]
            local _, _ = pcall(adapter.open_item, id, line)
        end
    end, { buffer = buf, silent = true, noremap = true })
    local _, _ = pcall(adapter.on_open, buf)
end

return M
