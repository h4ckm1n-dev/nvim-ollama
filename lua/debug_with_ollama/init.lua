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

-- Displays text in a dynamically sized floating window
local function display_in_floating_window(text)
  local lines = vim.split(text, "\n")
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  })
  return buf, win
end

-- Sets keymaps for the user's decision to replace text or not
local function set_keymaps_for_decision(buf, win, new_code)
  local function close_window()
    vim.api.nvim_win_close(win, true)
  end
  vim.api.nvim_buf_set_keymap(buf, "n", "y", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(new_code, "\n"))
      close_window()
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "n", "", { noremap = true, silent = true, callback = close_window })
  -- Ensure these keymaps only exist in this buffer
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
end

-- Main function to interact with the API
function M.AskOllama()
  local code_snippet = get_visual_selection()
  local prompt = "Improve this code: " .. code_snippet
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
  })

  if code ~= 200 then
    print("Failed to send debugging request. Response code: ", code)
    return
  end

  local response = table.concat(response_body)
  local buf, win = display_in_floating_window("API Response: " .. response .. "\nPress 'y' to replace, 'n' to cancel.")
  set_keymaps_for_decision(buf, win, response)
end

-- Setup function for lazy.nvim
function M.setup()
  vim.api.nvim_create_user_command("AskOllama", M.AskOllama, {})
end

return M