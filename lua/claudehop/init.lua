-- claudehop.nvim — a three-pane Claude Code panel for Neovim where every file
-- and symbol in the output is clickable and keyboard-hoppable.

local M = {}

function M.setup(opts)
  require("claudehop.config").setup(opts)
  require("claudehop.highlights").apply()
  require("claudehop.commands").setup()

  -- Re-apply our highlights when the colour scheme changes.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("claudehop_highlights", { clear = true }),
    callback = function()
      require("claudehop.highlights").apply()
    end,
  })
end

-- Convenience entry points so users can map functions directly.
function M.toggle()
  require("claudehop.ui").toggle()
end

function M.open()
  require("claudehop.ui").open()
end

function M.new_session()
  local session = require("claudehop.session")
  session.create()
  require("claudehop.ui").show(session.active())
end

function M.send(text)
  local session = require("claudehop.session")
  session.send(session.ensure(), text)
end

return M
