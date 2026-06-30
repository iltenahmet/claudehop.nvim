-- Talks to the Claude Code engine.
--
-- We run the real `claude` binary in its streaming JSON mode. That keeps one
-- long-lived process alive: we write user turns to its stdin and read events
-- back from its stdout, one JSON object per line. This is the same mechanism
-- the official editor integrations use, so we get full Claude Code behaviour
-- (skills, slash commands, MCP, memory files) without re-implementing any of it.

local M = {}

-- Start a Claude Code process.
--   cmd, args : the binary and its arguments
--   cwd       : working directory for the session
--   on_event  : called with each decoded JSON event
--   on_exit   : called with the exit code when the process ends
-- Returns the job id used to send input later.
function M.spawn(cmd, args, cwd, on_event, on_exit)
  local pending = "" -- holds a half-received line between stdout chunks

  local full = { cmd }
  vim.list_extend(full, args)

  local job = vim.fn.jobstart(full, {
    cwd = cwd,
    stdin = "pipe",
    on_stdout = function(_, data)
      if not data then
        return
      end
      -- Neovim splits stdout on newlines but a single line can span two
      -- callbacks, so we re-join and re-split against our own buffer.
      pending = pending .. table.concat(data, "\n")
      while true do
        local nl = pending:find("\n", 1, true)
        if not nl then
          break
        end
        local line = pending:sub(1, nl - 1)
        pending = pending:sub(nl + 1)
        if line ~= "" then
          local ok, obj = pcall(vim.json.decode, line)
          if ok and type(obj) == "table" then
            on_event(obj)
          end
        end
      end
    end,
    on_exit = function(_, code)
      if on_exit then
        on_exit(code)
      end
    end,
  })

  return job
end

-- Send a user turn to a running session.
function M.send(job, text)
  local msg = {
    type = "user",
    message = {
      role = "user",
      content = { { type = "text", text = text } },
    },
  }
  vim.fn.chansend(job, vim.json.encode(msg) .. "\n")
end

function M.stop(job)
  if job and job > 0 then
    pcall(vim.fn.jobstop, job)
  end
end

return M
