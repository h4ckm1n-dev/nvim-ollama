local M = {}

local http = require("socket.http")
local json = require("dkjson")
local ltn12 = require("ltn12")

local API_URL = "http://127.0.0.1:11434/api/generate"

-- Gets text from the current visual selection in Neovim
local function get_visual_selection()
  local _, start_row, _, _ = unpack(vim.fn.getpos("'<"))
  local _, end_row, _, _ = unpack(vim.fn.getpos("'>"))
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, true)
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n")
end

-- Extracts the actual message from the API response
local function extract_message(json_response)
  local decoded, _, err = json.decode(json_response)
  if err then
    print("Error decoding JSON: ", err)
    return "Error decoding response."
  end
  -- Assuming the message you want is in the 'response' field of the JSON
  local message = decoded.response or "No response field found."
  return message
end

-- Displays text in a split window on the right side taking 1/3 of the space
local function display_in_side_panel(text)
  -- Calculate width for the new window to take up 1/3 of the current Vim window
  local total_width = vim.o.columns
  local new_win_width = math.floor(total_width * 2 / 3)

  -- Split the window and adjust its width
  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  vim.api.nvim_win_set_width(0, new_win_width)

  -- Set up a new buffer for the extracted message
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n"))

  -- Set buffer properties
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  return buf
end

-- Sets keymaps for the user's decision to replace text or not
local function set_keymaps_for_decision(buf, new_code)
  local function close_window()
    -- Close the current window and return to the original window
    vim.cmd("wincmd h")
    vim.cmd("wincmd q")
  end

  vim.api.nvim_buf_set_keymap(buf, "n", "y", "", {
    noremap = true,
    silent = true,
    callback = function()
      -- Switch to the original window and replace the text
      vim.cmd("wincmd h")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(new_code, "\n"))
      close_window()
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "n", "", { noremap = true, silent = true, callback = close_window })
end

-- Function to create a floating window for user selection
local function create_floating_window(prompt, options)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(options, "\n"))

  -- Calculate window size and position
  local width = #prompt + 4
  local height = #vim.split(options, "\n") + 2
  local row = (vim.o.lines - height) / 2
  local col = (vim.o.columns - width) / 2

  -- Create floating window
  local opts = {
    style = "minimal",
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    focusable = true,
    border = "single",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)
  vim.api.nvim_win_set_option(win, "wrap", false)

  return win
end

-- Function to close floating window
local function close_floating_window(win)
  if win ~= nil and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- Main function to interact with the API
function M.AskOllama()
  local code_snippet = get_visual_selection()
  print("Code Snippet:\n", code_snippet)  -- Print the code snippet

  -- Show options in a floating window
  local prompt = "What would you like to do?"
  local options = {
    "1. Analyze",
    "2. Improve",
    "3. Debug",
  }
  local options_text = table.concat(options, "\n")
  local win = create_floating_window(prompt, options_text)

  -- Wait for user input
  local choice = nil
  local prompt_buf = vim.api.nvim_win_get_buf(win)
  while choice == nil do
    local _, input_key = vim.wait(100, function()
      return vim.api.nvim_buf_is_valid(prompt_buf)
    end, true)
    if input_key then
      if input_key == "1" or input_key == "2" or input_key == "3" then
        choice = input_key
      elseif input_key == "q" then
        close_floating_window(win)
        return
      end
    end
  end

  -- Close the floating window
  close_floating_window(win)

  -- Prepare data for API request
  local prompt = "Choice: " .. choice .. "\nCode Snippet:\n" .. code_snippet .. "\n\nImprove this code?"
  local data = {
    model = "mixtral",
    prompt = prompt,
    stream = false,
    max_tokens = 1000,
    temperature = 0.5,
    top_p = 1.0,
    frequency_penalty = 0.8,
    presence_penalty = 0.0,
    stop = "\n",
  }

  -- Send request to API
  local response_body = {}
  local _, code = http.request({
    url = API_URL,
    method = "POST",
    headers = { ["Content-Type"] = "application/json" },
    source = ltn12.source.string(json.encode(data)),
    sink = ltn12.sink.table(response_body),
    timeout = nil, 
  })

  -- Handle API response
  if code ~= 200 then
    print("Failed to send debugging request. Response code: ", code)
    return
  end

  local response = table.concat(response_body)
  local message = extract_message(response)
  print("API Response: " .. message)
end

-- Setup function for lazy.nvim
function M.setup()
  vim.api.nvim_create_user_command("AskOllama", M.AskOllama, {})
end

return M
