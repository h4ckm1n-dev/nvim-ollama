local API_URL = "http://127.0.0.1:11434/api/generate"
local vim = vim -- Ensure Neovim's 'vim' API is accessible

-- Function to create a floating window for better UX
local function create_float_window()
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")

    -- Calculate window size and position
    local win_height = math.ceil(height * 0.2)
    local win_width = math.ceil(width * 0.7)
    local row = math.ceil((height - win_height) / 2)
    local col = math.ceil((width - win_width) / 2)

    -- Window buffer and options
    local opts = {
        style = "minimal",
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col
    }

    local buf = vim.api.nvim_create_buf(false, true) -- Create a buffer for the window
    local win = vim.api.nvim_open_win(buf, true, opts) -- Open the window

    return buf, win
end

-- Function to display options in the floating window
local function display_options_in_window(buf, options)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, options)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
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
        local question = vim.fn.input("Enter your custom question: ")
        return question
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
        model = "code-davinci-002",
        prompt = prompt,
        temperature = 0.5,
        max_tokens = 1500,
        top_p = 1.0,
        frequency_penalty = 0.0,
        presence_penalty = 0.6,
        stop = {"\n"}
    })

    -- Send request to API
    local response = http_post(API_URL, data)

    -- Handle API response
    if response == nil then
        print("Failed to send request to the API.")
        return
    end

    local message = extract_message(response)
    print("API Response:\n", message)
end

-- Setup function for lazy.nvim
local function setup()
    vim.api.nvim_create_user_command("AskOllama", AskOllama, {})
end

return {
    AskOllama = AskOllama,
    setup = setup,
}
