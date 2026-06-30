-- References are the file names and locations that appear in Claude's output.
-- We mark each one in the conversation buffer and remember where it points, so
-- the user can jump from the chat straight to the spot in their code.

local M = {}

-- Namespace for the marks that highlight references and carry jump targets.
M.ns = vim.api.nvim_create_namespace("claudehop_refs")
-- Separate namespace for the temporary single-key labels used by hop().
M.hint_ns = vim.api.nvim_create_namespace("claudehop_hints")

-- Record one reference: highlight the text range and store its jump target.
local function add(session, lnum, scol, ecol, target)
  local id = vim.api.nvim_buf_set_extmark(session.conv_buf, M.ns, lnum, scol, {
    end_col = ecol,
    hl_group = "ClaudehopRef",
  })
  session.ref_targets[id] = target
end

-- Look at one rendered line of text and mark any references in it.
function M.scan(session, text, lnum)
  -- First pass: "path/to/file.ext:42" style references with a line number.
  local taken = {} -- byte ranges already claimed, so the second pass skips them
  local idx = 1
  while true do
    local s, e, file, line = text:find("([%w%._%-/]+%.[%w]+):(%d+)", idx)
    if not s then
      break
    end
    add(session, lnum, s - 1, e, { file = file, line = tonumber(line) })
    taken[#taken + 1] = { s, e }
    idx = e + 1
  end

  -- Second pass: bare file paths that contain a slash, e.g. "lua/foo/bar.lua".
  idx = 1
  while true do
    local s, e, file = text:find("([%w%._%-/]+/[%w%._%-]+%.[%w]+)", idx)
    if not s then
      break
    end
    local overlaps = false
    for _, r in ipairs(taken) do
      if s <= r[2] and e >= r[1] then
        overlaps = true
        break
      end
    end
    if not overlaps then
      add(session, lnum, s - 1, e, { file = file })
    end
    idx = e + 1
  end
end

-- Mark a reference at a known place (used for tool calls, where we already
-- know the file path and where it sits in the rendered line).
function M.mark(session, lnum, scol, ecol, target)
  add(session, lnum, scol, ecol, target)
end

-- Open a target in the editor column and move the cursor onto it.
function M.jump(target)
  if not target or not target.file then
    return
  end
  local ui = require("claudehop.ui")
  local win = ui.editor_win()
  vim.api.nvim_set_current_win(win)

  vim.cmd("edit " .. vim.fn.fnameescape(target.file))
  if target.line then
    pcall(vim.api.nvim_win_set_cursor, 0, { target.line, 0 })
  elseif target.search and target.search ~= "" then
    vim.fn.search(vim.fn.escape(target.search, [[\/.*$^~[]]), "w")
  end
  vim.cmd("normal! zz")
end

-- Jump using whatever reference sits under the cursor in the conversation.
function M.jump_at_cursor(session)
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1] - 1, pos[2]
  local marks = vim.api.nvim_buf_get_extmarks(
    session.conv_buf, M.ns, { row, 0 }, { row, -1 }, { details = true }
  )
  for _, m in ipairs(marks) do
    local id, mcol, det = m[1], m[3], m[4]
    local endcol = det.end_col or mcol
    if col >= mcol and col <= endcol then
      M.jump(session.ref_targets[id])
      return
    end
  end
  -- Nothing directly under the cursor: take the first reference on the line.
  if marks[1] then
    M.jump(session.ref_targets[marks[1][1]])
  end
end

-- Collect every reference mark in the buffer, sorted top to bottom.
local function all_marks(session)
  return vim.api.nvim_buf_get_extmarks(session.conv_buf, M.ns, 0, -1, {})
end

-- Move the cursor to the next or previous reference (dir = 1 or -1).
function M.cycle(session, dir)
  local marks = all_marks(session)
  if #marks == 0 then
    return
  end
  local cur = vim.api.nvim_win_get_cursor(0)
  local crow = cur[1] - 1
  local target
  if dir > 0 then
    for _, m in ipairs(marks) do
      if m[2] > crow then
        target = m
        break
      end
    end
    target = target or marks[1]
  else
    for i = #marks, 1, -1 do
      if marks[i][2] < crow then
        target = marks[i]
        break
      end
    end
    target = target or marks[#marks]
  end
  vim.api.nvim_win_set_cursor(0, { target[2] + 1, target[3] })
end

-- Label every reference currently on screen with a single key, wait for a
-- keypress, then jump to the one the user picked. This is the keyboard-only
-- "hop" to any file or symbol in the output.
function M.hop(session)
  local ui = require("claudehop.ui")
  local win = ui.conv_win
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local info = vim.fn.getwininfo(win)[1]
  local top, bot = info.topline - 1, info.botline - 1
  local marks = vim.api.nvim_buf_get_extmarks(
    session.conv_buf, M.ns, { top, 0 }, { bot, -1 }, {}
  )
  if #marks == 0 then
    return
  end

  local labels = "asdfghjklqwertyuiopzxcvbnm"
  local map = {}
  for i, m in ipairs(marks) do
    local ch = labels:sub(i, i)
    if ch == "" then
      break
    end
    map[ch] = session.ref_targets[m[1]]
    vim.api.nvim_buf_set_extmark(session.conv_buf, M.hint_ns, m[2], m[3], {
      virt_text = { { ch, "ClaudehopHint" } },
      virt_text_pos = "overlay",
    })
  end

  vim.cmd("redraw")
  local ok, ch = pcall(vim.fn.getcharstr)
  vim.api.nvim_buf_clear_namespace(session.conv_buf, M.hint_ns, 0, -1)
  if ok and map[ch] then
    M.jump(map[ch])
  end
end

return M
