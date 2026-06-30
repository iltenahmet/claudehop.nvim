-- Turns the JSON events from a Claude Code session into readable lines in the
-- conversation buffer, and marks the file references inside them.

local M = {}
local refs = require("claudehop.refs")

-- Namespace for whole-line highlights (prompts, tool calls, meta lines).
M.line_ns = vim.api.nvim_create_namespace("claudehop_lines")

-- Append lines to the conversation buffer and return the index of the first
-- new line. The buffer is read-only for the user, so we flip it modifiable
-- just for the write.
local function append(session, lines, hl)
  local buf = session.conv_buf
  vim.bo[buf].modifiable = true

  local count = vim.api.nvim_buf_line_count(buf)
  local start
  -- Replace the single empty line a fresh buffer starts with.
  if count == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
    start = 0
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, lines)
  else
    start = count
    vim.api.nvim_buf_set_lines(buf, start, start, false, lines)
  end

  vim.bo[buf].modifiable = false

  if hl then
    for i = 0, #lines - 1 do
      vim.api.nvim_buf_set_extmark(buf, M.line_ns, start + i, 0, {
        end_row = start + i + 1,
        hl_group = hl,
        hl_eol = true,
      })
    end
  end

  M.scroll(session)
  return start
end

-- Keep the conversation scrolled to the newest line if its window is visible.
function M.scroll(session)
  local ui = require("claudehop.ui")
  local win = ui.conv_win
  if win and vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_buf(win) == session.conv_buf then
    local last = vim.api.nvim_buf_line_count(session.conv_buf)
    pcall(vim.api.nvim_win_set_cursor, win, { last, 0 })
  end
end

-- Render a block of assistant text, scanning each line for references.
local function append_text(session, text)
  local lines = vim.split(text, "\n", { plain = true })
  local start = append(session, lines)
  for i, line in ipairs(lines) do
    refs.scan(session, line, start + i - 1)
  end
end

-- Turn one input value into a short string for display.
local function scalar(v)
  local t = type(v)
  if t == "string" then
    return v
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t == "table" then
    -- Show small arrays inline (e.g. a list of paths), skip large/nested ones.
    if vim.islist(v) and #v > 0 and #v <= 6 then
      local parts = {}
      for _, item in ipairs(v) do
        if type(item) == "string" or type(item) == "number" then
          parts[#parts + 1] = tostring(item)
        end
      end
      if #parts == #v then
        return table.concat(parts, ", ")
      end
    end
  end
  return nil
end

-- Build a short, readable summary of any tool's input by showing its fields as
-- `key: value`. This works for every tool, including ones added in the future,
-- so we never keep a per-tool list. The full input is always in the log.
local function tool_summary(input)
  local keys = {}
  for k in pairs(input) do
    keys[#keys + 1] = k
  end
  table.sort(keys)

  local parts = {}
  for _, k in ipairs(keys) do
    local s = scalar(input[k])
    if s and s ~= "" then
      -- A single field needs no key prefix; several fields are clearer with it.
      parts[#parts + 1] = { key = k, value = s }
    end
  end

  if #parts == 0 then
    return nil
  elseif #parts == 1 then
    return parts[1].value
  end

  local out = {}
  for _, p in ipairs(parts) do
    out[#out + 1] = p.key .. ": " .. p.value
  end
  return table.concat(out, "  ·  ")
end

-- Render a tool call (an Edit, Write, Bash, Grep, ...). When the tool acts on
-- a file we mark that file path so the user can jump to it. The full input is
-- always recorded in the log (:ClaudeHopLog).
local function append_tool(session, block)
  local name = block.name or "tool"
  local input = block.input or {}
  local file = input.file_path or input.path or input.notebook_path

  local summary = tool_summary(input)
  -- Keep the first line readable; the full text is in the log if it is long.
  if summary then
    summary = summary:gsub("\n", " ⏎ ")
    if #summary > 200 then
      summary = summary:sub(1, 200) .. " …"
    end
  end

  local label = "  ⚙ " .. name
  if summary then
    label = label .. "  " .. summary
  end
  local lnum = append(session, { label }, "ClaudehopTool")

  if file then
    local scol = label:find(file, 1, true)
    if scol then
      scol = scol - 1
      local target = { file = file }
      -- For an edit, land on the first line of the new text.
      if type(input.new_string) == "string" then
        target.search = input.new_string:match("^[^\n]*")
      end
      refs.mark(session, lnum, scol, scol + #file, target)
    end
  end
end

-- Show the user's own prompt above Claude's reply.
function M.append_prompt(session, text)
  local lines = { "" }
  for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
    table.insert(lines, "❯ " .. l)
  end
  append(session, lines, "ClaudehopPrompt")
end

-- Handle one decoded event from the Claude Code process.
function M.on_event(session, ev)
  local t = ev.type

  if t == "system" and ev.subtype == "init" then
    session.session_id = ev.session_id
    local short = (ev.session_id or "?"):sub(1, 8)
    append(session, { "── session " .. short .. " ──" }, "ClaudehopMeta")

  elseif t == "assistant" then
    local msg = ev.message or {}
    for _, block in ipairs(msg.content or {}) do
      if block.type == "text" and block.text and block.text ~= "" then
        append_text(session, block.text)
      elseif block.type == "tool_use" then
        append_tool(session, block)
      end
    end

  elseif t == "result" then
    M.set_status(session, false)

  end
  -- Other event types (tool results, partial stream events) are ignored in v0.
end

function M.on_exit(session, code)
  M.set_status(session, false)
  append(session, { "── session ended (" .. tostring(code) .. ") ──" }, "ClaudehopMeta")
end

-- Show whether the session is currently working, in the conversation winbar.
function M.set_status(session, busy)
  session.busy = busy
  local ui = require("claudehop.ui")
  local win = ui.conv_win
  if win and vim.api.nvim_win_is_valid(win) then
    local total = #require("claudehop.session").sessions
    vim.wo[win].winbar = table.concat({
      "  claudehop",
      "session " .. tostring(session.n) .. "/" .. tostring(total),
      (busy and "● working…" or "○ idle"),
      "C-n new · C-←/→ switch · f hop · ⏎ jump",
    }, "  ·  ")
  end
end

return M
