-- Builds and manages the panel layout: the editor on the left, the Claude
-- conversation on the right, and the prompt box below the conversation.

local M = {}
local config = require("claudehop.config")
local session = require("claudehop.session")

M.conv_win = nil      -- window showing the conversation
M.input_win = nil     -- window showing the prompt box
M.editor_window = nil -- the editor window we jump back into

-- True when the panel windows are currently on screen.
function M.is_open()
  return M.conv_win and vim.api.nvim_win_is_valid(M.conv_win)
end

local function is_panel(win)
  return win == M.conv_win or win == M.input_win
end

-- Find a window to open files in: the remembered editor window if it is still
-- a normal window, otherwise any non-panel window, otherwise a fresh split.
function M.editor_win()
  if M.editor_window
    and vim.api.nvim_win_is_valid(M.editor_window)
    and not is_panel(M.editor_window) then
    return M.editor_window
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_panel(w) then
      M.editor_window = w
      return w
    end
  end
  vim.api.nvim_set_current_win(M.conv_win)
  vim.cmd("topleft vsplit")
  M.editor_window = vim.api.nvim_get_current_win()
  return M.editor_window
end

-- Point the panel windows at a given session's buffers.
function M.show(sess)
  if not M.is_open() then
    return
  end
  vim.api.nvim_win_set_buf(M.conv_win, sess.conv_buf)
  vim.api.nvim_win_set_buf(M.input_win, sess.input_buf)
  require("claudehop.render").set_status(sess, sess.busy)
end

local function set_win_opts(win, conversation)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winfixwidth = true
  vim.wo[win].wrap = conversation
  vim.wo[win].cursorline = conversation
end

-- Open the three-pane layout, starting a session if needed.
function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(M.input_win)
    return
  end

  local cfg = config.options
  local sess = session.ensure()

  -- Remember the window we came from so jumps land back in the editor.
  M.editor_window = vim.api.nvim_get_current_win()

  -- Conversation column on the right.
  vim.cmd("botright vsplit")
  M.conv_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(M.conv_win, math.floor(vim.o.columns * cfg.layout.width))
  vim.api.nvim_win_set_buf(M.conv_win, sess.conv_buf)
  set_win_opts(M.conv_win, true)

  -- Prompt box below it.
  vim.cmd("belowright split")
  M.input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(M.input_win, cfg.layout.input_height)
  vim.api.nvim_win_set_buf(M.input_win, sess.input_buf)
  set_win_opts(M.input_win, false)

  require("claudehop.render").set_status(sess, sess.busy)

  -- Land in the prompt box, ready to type.
  vim.api.nvim_set_current_win(M.input_win)
end

-- Hide the panel windows (the sessions and their buffers stay alive).
function M.close()
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_win_close(M.input_win, true)
  end
  if M.conv_win and vim.api.nvim_win_is_valid(M.conv_win) then
    vim.api.nvim_win_close(M.conv_win, true)
  end
  M.conv_win = nil
  M.input_win = nil
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

return M
