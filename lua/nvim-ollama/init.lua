-- Define the API URL
local API_URL = "http://127.0.0.1:11434/api/generate"

-- Ensure Neovim's 'vim' API is accessible
local vim = vim

-- Function to create a floating window for better UX
local function create_float_window()
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    local win_height = math.ceil(height * 0.2)
    local win_width = math.ceil(width * 0.7)
    local row = math.ceil((height - win_height) / 2)
    local col = math.ceil((width - win_width) / 2)
    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col
    }
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, opts)
    return buf, win
end

-- Function to display options in the floating window
local function display_options_in_window(buf, options)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, options)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

-- Fetches the text selected in visual mode
local function get_visual_selection()
    local _, start_row, _, _ = unpack(vim.fn.getpos("'<"))
    local _, end_row, _, _ = unpack(vim.fn.getpos("'>"))
    local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, true)
    if #lines == 0 then return "" end
    return table.concat(lines, "\n")
end

-- Extracts the message from the API's JSON response
local function extract_message(json_response)
    local decoded = vim.fn.json_decode(json_response)
    if not decoded then
        print("Error decoding JSON")
        return "Error decoding response."
    end
    local message = decoded.response or "No response field found."
    return message
end

-- Sends a POST request to the specified API
local function http_post(url, data)
    local cmd = string.format("curl -s -X POST -H 'Content-Type: application/json' -d '%s' %s", data, url)
    local handle = io.popen(cmd)
    local response = handle:read("*a")
    handle:close()
    return response
end

-- Improved user choice function with floating window
local function user_choice()
    local buf, win = create_float_window()
    local options = {"1. Improve Code", "2. Debug Code", "3. Custom Question"}
    display_options_in_window(buf, options)
    local choice = tonumber(vim.fn.input("Option (1/2/3): "))
    vim.api.nvim_win_close(win, true) -- Close the floating window after selection
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

-- Main function to interact with the API
local function AskOllama()
    local code_snippet = get_visual_selection()
    local action_or_question = user_choice()
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
    
    -- Create a new buffer for the API response
    local response_buf = vim.api.nvim_create_buf(true, false)
    
    -- Format the response
    local formatted_response = {}
    for json_response in response:gmatch("{.-}") do
        local decoded_response = vim.fn.json_decode(json_response)
        local message = decoded_response.response or "No response found."
        table.insert(formatted_response, "API Response:")
        table.insert(formatted_response, "-----------------------")
        for line in message:gmatch("[^\r\n]+") do
            table.insert(formatted_response, line)
        end
        table.insert(formatted_response, "")
    end
    
    -- Set the lines in the new buffer
    vim.api.nvim_buf_set_lines(response_buf, 0, -1, false, formatted_response)

    -- Open the new buffer in a split at the bottom
    vim.cmd('botright vsplit')
    vim.api.nvim_buf_set_option(response_buf, 'modifiable', false)
    vim.cmd('wincmd l') -- Move focus to the new split
end


-- Setup function for lazy.nvim
local function setup()
    vim.api.nvim_create_user_command("AskOllama", AskOllama, {})
end

return {
    AskOllama = AskOllama,
    setup = setup,
}
