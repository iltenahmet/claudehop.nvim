-- Guard so the plugin is only loaded once.
if vim.g.loaded_claudehop then
  return
end
vim.g.loaded_claudehop = true

-- The real setup happens when the user calls require("claudehop").setup().
-- We still register a minimal command here so the panel can be opened even if
-- setup() has not run yet (it will run setup with defaults on first use).
vim.api.nvim_create_user_command("ClaudeHop", function()
  require("claudehop").setup()
  require("claudehop.ui").toggle()
end, { desc = "Toggle the claudehop panel (loads claudehop with defaults)" })
