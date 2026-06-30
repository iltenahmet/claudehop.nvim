-- User commands.

local M = {}

function M.setup()
  local ui = require("claudehop.ui")
  local session = require("claudehop.session")

  vim.api.nvim_create_user_command("ClaudeHop", function()
    ui.toggle()
  end, { desc = "Toggle the claudehop panel" })

  vim.api.nvim_create_user_command("ClaudeHopOpen", function()
    ui.open()
  end, { desc = "Open the claudehop panel" })

  vim.api.nvim_create_user_command("ClaudeHopNew", function()
    session.create()
    if not ui.is_open() then
      ui.open()
    else
      ui.show(session.active())
    end
  end, { desc = "Start a new claudehop session" })

  vim.api.nvim_create_user_command("ClaudeHopLog", function()
    require("claudehop.log").open()
  end, { desc = "Show the raw claudehop process log" })

  vim.api.nvim_create_user_command("ClaudeHopSend", function(opts)
    local sess = session.ensure()
    if not ui.is_open() then
      ui.open()
    end
    require("claudehop.render").append_prompt(sess, opts.args)
    session.send(sess, opts.args)
  end, { nargs = "+", desc = "Send a prompt to the active claudehop session" })
end

return M
