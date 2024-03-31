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
    -- Open a new horizontal split at the bottom
    vim.cmd('botright new')
    local height = math.floor(vim.api.nvim_get_option("lines") * 0.3) -- Use 30% of the total lines
    vim.api.nvim_win_set_height(0, height)

    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    local full_text = ""
    local all_done = false

    for line in response:gmatch("[^\r\n]+") do
        local json_response = vim.fn.json_decode(line)
        if json_response and json_response.response then
            -- Check if the fragment ends with a punctuation mark before adding a space
            if full_text:match("[%.%,%;%:%?!]$") or json_response.response == "" then
                full_text = full_text .. json_response.response
            else
                full_text = full_text .. (full_text ~= "" and " " or "") .. json_response.response
            end
        end
        if json_response and json_response.done then
            all_done = json_response.done
            break -- Stop processing once the final part of the response is received
        end
    end

    if not all_done then
        print("Response not fully received or missing 'done' confirmation.")
        return
    end

    local response_lines = vim.split(full_text, "\n", true)
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