local API_URL = "http://127.0.0.1:11434/api/generate"

-- Function to create a floating window for displaying information or errors
local function create_float_window()
    local width, height = vim.api.nvim_get_option("columns"), vim.api.nvim_get_option("lines")
    local win_height, win_width = math.ceil(height * 0.2), math.ceil(width * 0.7)
    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = math.ceil((height - win_height) / 2),
        col = math.ceil((width - win_width) / 2)
    }
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, opts)
    return buf, win
end

-- Function to get content from the clipboard
local function get_clipboard_content()
    local clipboard_content = vim.fn.getreg("+") -- Use "*" for the "*" register if needed
    if clipboard_content == "" then
        print("Clipboard is empty.")
        return ""
    end
    return clipboard_content
end

-- Function to perform an HTTP POST request
local function http_post(url, data)
    local cmd = string.format("curl -s -X POST -H 'Content-Type: application/json' -d '%s' %s", data, url)
    local handle = io.popen(cmd)
    local response = handle:read("*a")
    handle:close()
    return response
end

-- Main function to ask the user for a question, get clipboard content, and send to API
local function AskOllama()
    local code_snippet = get_clipboard_content()
    if code_snippet == "" then
        return -- Exit if the clipboard is empty
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
    print(response) -- Handle the response appropriately, maybe display it in a floating window or a new buffer
end

-- Function to set up the user command
local function setup()
    vim.api.nvim_create_user_command("AskOllama", AskOllama, {})
end

return {
    AskOllama = AskOllama,
    setup = setup,
}
