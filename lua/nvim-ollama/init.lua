local API_URL = "http://127.0.0.1:11434/api/generate"

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

local function display_options_in_window(buf, options)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, options)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function get_visual_selection()
    local start_row, end_row = vim.fn.getpos("'<")[2], vim.fn.getpos("'>")[2]
    return table.concat(vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, true), "\n")
end

local function extract_message(json_response)
    local decoded = vim.fn.json_decode(json_response)
    if not decoded then
        print("Error decoding JSON")
        return "Error decoding response."
    end
    return decoded.response or "No response field found."
end

local function http_post(url, data)
    local cmd = string.format("curl -s -X POST -H 'Content-Type: application/json' -d '%s' %s", data, url)
    local handle = io.popen(cmd)
    local response = handle:read("*a")
    handle:close()
    return response
end

local function user_choice()
    local buf, win = create_float_window()
    local options = {"1. Improve Code", "2. Debug Code", "3. Custom Question"}
    display_options_in_window(buf, options)
    local choice = tonumber(vim.fn.input("Option (1/2/3): "))
    vim.api.nvim_win_close(win, true)
    if choice == 1 then
        return "Improve this code:"
    elseif choice == 2 then
        return "Debug this code:"
    elseif choice == 3 then
        return vim.fn.input("Enter your custom question: ")
    else
        print("Invalid option, defaulting to improving code.")
        return "Improve this code:"
    end
end

local function format_and_display_response(response)
    local response_buf = vim.api.nvim_create_buf(true, false)
    -- Create a horizontal split at the bottom for the new buffer
    vim.cmd('botright split new')
    vim.api.nvim_win_set_buf(0, response_buf)  -- Ensure the new buffer is displayed in the newly created window
    local formatted_response = {"API Response:", "-----------------------"}
    for json_response in response:gmatch("{.-}") do
        local message = extract_message(json_response)
        for line in message:gmatch("[^\r\n]+") do
            table.insert(formatted_response, line)
        end
        table.insert(formatted_response, "")
    end
    vim.api.nvim_buf_set_lines(response_buf, 0, -1, false, formatted_response)
    vim.api.nvim_buf_set_option(response_buf, 'modifiable', false)
    -- Move focus to the new split. The 'wincmd p' command switches to the previous (in this context, newly created) window.
    vim.cmd('wincmd p')
end

local function AskOllama()
    local code_snippet, action_or_question = get_visual_selection(), user_choice()
    local prompt = "Code Snippet:\n" .. code_snippet .. "\n\n" .. action_or_question
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
    format_and_display_response(response)
end

local function setup()
    vim.api.nvim_create_user_command("AskOllama", AskOllama, {})
end

return {
    AskOllama = AskOllama,
    setup = setup,
}
