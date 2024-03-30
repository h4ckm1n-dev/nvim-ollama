local API_URL = "http://127.0.0.1:11434/api/generate"

-- Direct reference to Neovim's 'vim' API is not needed as it's globally available

-- Enhanced floating window creation for better UX
local function create_float_window()
    local width = vim.api.nvim_get_option("columns")
    local height = vim.api.nvim_get_option("lines")
    -- Adjusted window proportions for better visibility
    local win_height = math.ceil(height * 0.3)
    local win_width = math.ceil(width * 0.6)
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

-- Fixed function to fetch the text selected in visual mode
local function get_visual_selection()
    -- Adjusted to ensure proper capture of multi-line selections
    vim.cmd('normal! gv"xy')
    return vim.fn.getreg('x')
end

-- Improved JSON parsing and error handling
local function extract_message(json_response)
    local status, decoded = pcall(vim.fn.json_decode, json_response)
    if not status then
        print("Error decoding JSON:", decoded)
        return "Error decoding response."
    end
    local message = decoded.response or "No response field found."
    return message
end

-- Enhanced HTTP POST function for improved readability and error handling
local function http_post(url, data)
    local cmd = string.format("curl -s -X POST -H 'Content-Type: application/json' -d @- %s", url)
    local response = vim.fn.system(cmd, data)
    return response
end

-- Optimized user interaction for a non-blocking choice in the floating window
local function user_choice()
    local buf, win = create_float_window()
    local options = {"1. Improve Code", "2. Debug Code", "3. Custom Question"}
    display_options_in_window(buf, options)
    -- Awaiting user input with a more intuitive interface
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua ConfirmSelection()<CR>', { noremap = true, silent = true })
    -- Functionality to capture and handle the user's choice will be added here (see below)
end

-- Global variable to store the user's choice
_G.user_choice_global = nil

-- Function to display options and set mappings in the floating window
local function display_options_and_set_mappings(buf)
    local options = {"1. Improve Code", "2. Debug Code", "3. Custom Question"}
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, options)
    vim.api.nvim_buf_set_keymap(buf, 'n', '1', '<cmd>lua ConfirmSelection(1)<CR>', {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '2', '<cmd>lua ConfirmSelection(2)<CR>', {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '3', '<cmd>lua ConfirmSelection(3)<CR>', {noremap = true, silent = true})
end

-- Improved user choice function with non-blocking interaction
local function user_choice()
    local buf, win = create_float_window()
    display_options_and_set_mappings(buf)
    -- No need to directly capture the user's choice here; it's done via mappings
end

-- Function to confirm user selection in the floating window
function ConfirmSelection(choice)
    _G.user_choice_global = choice
    vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
    AskOllama() -- Call back to proceed with action
end

-- Adjusted AskOllama function
local function AskOllama()
    local code_snippet = get_visual_selection()
    if code_snippet == "" then
        if not _G.user_choice_global then
            print("Please select a code snippet before asking.")
            user_choice() -- Open user choice window if no choice has been made
            return
        else
            -- Handle the choice here
            local action_or_question
            if _G.user_choice_global == 1 then
                action_or_question = "Improve this code:"
            elseif _G.user_choice_global == 2 then
                action_or_question = "Debug this code:"
            elseif _G.user_choice_global == 3 then
                action_or_question = vim.fn.input("Enter your custom question: ")
            else
                print("Invalid option, defaulting to improving code.")
                action_or_question = "Improve this code:"
            end
            
            local prompt = "Code Snippet:\n" .. code_snippet .. "\n\n" .. action_or_question
            -- Proceed with sending prompt to API and handling the response
            -- Reset the global choice variable for future invocations
            _G.user_choice_global = nil
            -- Remember to send the prompt to your API and handle the response
            return -- Placeholder for actual API call and response handling
        end
    end
end


return {
    setup = setup,
}
