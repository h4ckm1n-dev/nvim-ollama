## nvim-ollama

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    {
      "h4ckm1n-dev/nvim-ollama",
      config = function()
        require("nvim-ollama").setup()
      end
    },
    { import = "plugins" },