-- Buffer-local key mappings for a session's conversation and prompt buffers.

local M = {}
local config = require("claudehop.config")
local refs = require("claudehop.refs")
local session = require("claudehop.session")
local ui = require("claudehop.ui")

-- Mappings shared by both the conversation and the prompt box.
local function attach_common(buf, sess)
  local km = config.options.keymaps
  local function map(mode, lhs, fn)
    if lhs and lhs ~= "" then
      vim.keymap.set(mode, lhs, fn, { buffer = buf, nowait = true, silent = true })
    end
  end
  map("n", km.new_session, function()
    session.create()
    ui.show(session.active())
  end)
  map("n", km.next_session, function()
    session.switch(1)
  end)
  map("n", km.prev_session, function()
    session.switch(-1)
  end)
end

function M.attach(sess)
  local km = config.options.keymaps

  -- Conversation buffer: navigate and jump to references.
  local cbuf = sess.conv_buf
  local function cmap(mode, lhs, fn)
    if lhs and lhs ~= "" then
      vim.keymap.set(mode, lhs, fn, { buffer = cbuf, nowait = true, silent = true })
    end
  end
  cmap("n", km.jump, function()
    refs.jump_at_cursor(sess)
  end)
  cmap("n", km.next_ref, function()
    refs.cycle(sess, 1)
  end)
  cmap("n", km.prev_ref, function()
    refs.cycle(sess, -1)
  end)
  cmap("n", km.hop, function()
    refs.hop(sess)
  end)
  -- A mouse click that lands on a reference also jumps.
  cmap("n", "<2-LeftMouse>", function()
    refs.jump_at_cursor(sess)
  end)
  attach_common(cbuf, sess)

  -- Prompt box: send the typed text.
  local ibuf = sess.input_buf
  local function imap(mode, lhs, fn)
    if lhs and lhs ~= "" then
      vim.keymap.set(mode, lhs, fn, { buffer = ibuf, nowait = true, silent = true })
    end
  end
  imap("n", km.submit, function()
    session.submit(sess)
  end)
  imap("i", km.submit_insert, function()
    vim.cmd("stopinsert")
    session.submit(sess)
  end)
  attach_common(ibuf, sess)
end

return M
