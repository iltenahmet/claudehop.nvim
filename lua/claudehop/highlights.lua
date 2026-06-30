-- Default colours. Each group links to a standard highlight so it inherits
-- from the user's colour scheme, and uses `default = true` so a user can
-- override any of them without us clobbering their choice.

local M = {}

local links = {
  ClaudehopRef = "Underlined",   -- a clickable file/symbol reference
  ClaudehopTool = "Comment",     -- a tool call line (Edit, Write, ...)
  ClaudehopMeta = "NonText",     -- session start/end separators
  ClaudehopPrompt = "Title",     -- the user's own prompt
  ClaudehopHint = "IncSearch",   -- the single-key labels used by hop()
}

function M.apply()
  for group, target in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
end

return M
