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
	local decoded = vim.fn.json_decode(json_response)
	if decoded == nil then
		print("Error decoding JSON")
		return "Error decoding response."
	end
	-- Assuming the message you want is in the 'response' field of the JSON
	local message = decoded.response or "No response field found."
	return message
end

-- Function to make an HTTP POST request
local function http_post(url, data)
	local command = string.format("curl -X POST -H 'Content-Type: application/json' -d '%s' %s", data, url)
	local handle = io.popen(command)
	local response = handle:read("*a")
	handle:close()
	return response
end

-- Main function to interact with the API
local function AskOllama()
	local code_snippet = get_visual_selection()
	print("Code Snippet:\n", code_snippet) -- Print the code snippet

	-- Prepare data for API request
	local prompt = "Code Snippet:\n" .. code_snippet .. "\n\nWhat would you like to do?"
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
	local encoded_data = vim.fn.json_encode(data)

	-- Send request to API
	local response = http_post(API_URL, encoded_data)

	-- Handle API response
	if response == nil then
		print("Failed to send debugging request.")
		return
	end

	local message = extract_message(response)
	print("API Response: " .. message)
end

-- Setup function for lazy.nvim
local function setup()
	vim.api.nvim_create_user_command("AskOllama", AskOllama, {})
end

return {
	AskOllama = AskOllama,
	setup = setup,
}
