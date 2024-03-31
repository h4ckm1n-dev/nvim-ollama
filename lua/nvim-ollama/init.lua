local vim = require('vim')
local io = require('io')

local function get_clipboard_content()
    local clipboard_content = vim.fn.getreg("+")
    if clipboard_content == "" then
        print("Clipboard is empty.")
        return ""
    end
    return clipboard_content
end

local function http_post(url, data)
    local cmd = string.format("curl -s -X POST -H 'Content-Type: application/json' -d '%s' %s", data, url)
    local handle = io.popen(cmd)
    if not handle then
        print("Failed to execute curl command.")
        return ""
    end
    local response = handle:read("*a")
    handle:close()
    if not response then
        print("Failed to read response from curl command.")
        return ""
    end
    return response
end

local function format_and_display_response(response)
    -- Open a new horizontal split at the bottom
    vim.cmd('botright split')
    local height = math.floor(vim.api.nvim_get_option("lines") * 0.3) -- Use 30% of the total lines
    vim.api.nvim_win_set_height(0, height)

    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    -- Convert JSON response to Lua table
    local json_response = vim.fn.json_decode(response)
    if not json_response then
        print("Failed to decode JSON response.")
        return
    end

    local markdown_output = "```\n" -- Start Markdown code block

    -- Iterate over JSON fields and format them as Markdown
    for _, entry in ipairs(json_response) do
        markdown_output = markdown_output .. entry.response .. " "
    end

    markdown_output = markdown_output .. "```" -- End Markdown code block

    -- Set Markdown content in the buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {markdown_output})
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function AskOllama()
    local code_snippet = get_clipboard_content()
    if code_snippet == "" then
        return
    end
    local question = vim.fn.input("Enter your question: ")
    local prompt = "Code Snippet:\n" .. code_snippet .. "\n\nQuestion:\n" .. question
    local data = vim.fn.json_encode({
        model = "mixtral",
        prompt = prompt,
        temperature = 0.5,
        max_tokens = 1500,
        top_p = 1.0,
        frequency_penalty = 0.0,
        presence_penalty = 0.6,
        stop = {"\n"}
    })
    local response = http_post(API_URL, data)
    if response == "" then
        print("Failed to get a response.")
        return
    end
    format_and_display_response(response)
end

local function setup()
    vim.api.nvim_create_user_command("AskOllama", AskOllama, {})
end

return {
    AskOllama = AskOllama,
    setup = setup,
}