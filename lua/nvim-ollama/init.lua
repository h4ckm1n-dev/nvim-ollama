local API_URL = "http://127.0.0.1:11434/api/generate"

-- Function to fetch the clipboard content.
local function get_clipboard_content()
    local clipboard_content = vim.fn.getreg("+") -- Use `"*"` instead of `"+"` if needed.
    if clipboard_content == "" then
        print("Clipboard is empty.")
        return nil
    end
    return clipboard_content
end

-- Function to post data to the API and handle the response.
local function http_post(url, data, callback)
    local cmd = string.format("curl -s -X POST -H 'Content-Type: application/json' -d '%s' %s", vim.fn.shellescape(data), url)
    vim.fn.jobstart(cmd, {
        on_stdout = function(_, data)
            callback(table.concat(data, "\n"))
        end,
        stdout_buffered = true,
    })
end

-- Function to ask the user for their choice.
local function user_choice(callback)
    local choices = {"Improve this code", "Debug this code", "Custom Question"}
    local choice = vim.fn.inputlist(choices)
    if choice < 1 or choice > #choices then
        print("Invalid selection.")
        return
    elseif choice == 3 then
        local customQuestion = vim.fn.input("Enter your custom question: ")
        callback(customQuestion)
    else
        callback(choices[choice])
    end
end

-- Main function to send the clipboard content and ask the user what they want to do.
local function AskOllama()
    local code_snippet = get_clipboard_content()
    if not code_snippet then return end -- Exit if clipboard is empty.

    user_choice(function(action_or_question)
        local prompt = string.format("Code Snippet:\n%s\n\n%s:", code_snippet, action_or_question)
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

        http_post(API_URL, data, function(response)
            print(response) -- Simple print, adjust as needed for formatting/displaying.
        end)
    end)
end

-- Setup command to call the main function.
vim.api.nvim_create_user_command("AskOllama", AskOllama, {})

return {
    AskOllama = AskOllama,
}
