local API_URL = "http://127.0.0.1:11434/api/generate"

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
    vim.cmd('botright vnew')
    local width = math.floor(vim.api.nvim_get_option("columns") * 0.3)
    vim.api.nvim_win_set_width(0, width)

    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    local full_response = {}
    local all_done = false

    for line in response:gmatch("[^\r\n]+") do
        local json_response = vim.fn.json_decode(line)
        if json_response and json_response.response then
            table.insert(full_response, json_response.response)
        end
        if json_response and json_response.done then
            all_done = json_response.done
        end
    end

    if not all_done then
        print("Response not fully received.")
        return
    end

    -- Combine all response parts into a single string, as they might have been split
    local combined_response = table.concat(full_response, "\n")

    -- Split the combined response into lines to properly display in the buffer
    local response_lines = vim.split(combined_response, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, response_lines)
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
