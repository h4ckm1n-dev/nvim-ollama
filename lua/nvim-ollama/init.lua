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

-- Displays text in a floating window for clearer prompts
local function display_floating_prompt(prompt_title, prompt_options)
  local content = prompt_title .. "\n" .. table.concat(prompt_options, "\n")
  local height = #prompt_options + 1
  local width = #prompt_title + 2
  local row = (vim.o.lines - height) / 2
  local col = (vim.o.columns - width) / 2

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, prompt_options)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local opts = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    focusable = true,
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)
  return win, buf
end

-- Main function to interact with the API with interactive mode
function M.AskOllama()
  local code_snippet = get_visual_selection()
  
  -- Prompt the user for an action using a floating window
  local choice_win, choice_buf = display_floating_prompt("Choose an action:", {"1: Improve", "2: Debug", "3: Analyse", "4: Custom"})

  local choice

  -- Wait for the user to make a choice
  while true do
    local _, line_nr = vim.api.nvim_win_get_cursor(choice_win)
    choice = vim.api.nvim_buf_get_lines(choice_buf, line_nr - 1, line_nr, false)[1]
    if choice then
      choice = tonumber(choice:match("%d+"))
      if choice and choice >= 1 and choice <= 4 then
        break
      end
    end
  end

  local action
  local custom_prompt

  -- Match the choice with the corresponding action
  if choice == 1 then
    action = "Improve"
  elseif choice == 2 then
    action = "Debug"
  elseif choice == 3 then
    action = "Analyse"
  elseif choice == 4 then
    custom_prompt = vim.fn.input("Enter your custom prompt: ")
    action = "Custom"
  end

  local prompt
  if action == "Custom" and custom_prompt ~= "" then
    prompt = custom_prompt .. " " .. code_snippet
  else
    prompt = action .. " this code: " .. code_snippet
  end

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

  local response_body = {}
  local _, code = http.request({
    url = API_URL,
    method = "POST",
    headers = { ["Content-Type"] = "application/json" },
    source = ltn12.source.string(json.encode(data)),
    sink = ltn12.sink.table(response_body),
    timeout = nil, 
  })

  if code ~= 200 then
    print("Failed to send request. Response code: ", code)
    return
  end

  local response = table.concat(response_body)
  local message = extract_message(response)
  local buf = display_in_side_panel("API Response: " .. message .. "\nPress 'y' to replace, 'n' to cancel.")
  set_keymaps_for_decision(buf, message)

  vim.api.nvim_win_close(choice_win, true)
end

-- Setup function for lazy.nvim
function M.setup()
  vim.api.nvim_create_user_command("AskOllama", M.AskOllama, {})
end

return M
