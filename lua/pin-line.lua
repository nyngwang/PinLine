local NOREF_NOERR_TRUNC = { noremap = true, silent = true, nowait = true }
local NOREF_NOERR = { noremap = true, silent = true }
local EXPR_NOREF_NOERR_TRUNC = { expr = true, noremap = true, silent = true, nowait = true }
---------------------------------------------------------------------------------------------------

local M = {}


local function pin_to_80_percent_height()
  local scrolloff = 7
  local cur_line = vim.fn.line('.')
  vim.cmd('normal! zt')
  if (cur_line > scrolloff) then
    vim.cmd('normal!' .. scrolloff .. 'k' .. scrolloff .. 'j')
  else
    vim.cmd('normal!' .. (cur_line-1) .. 'k' .. (cur_line-1) .. 'j')
  end
end
---------------------------------------------------------------------------------------------------
local win_states = {}

local opts = {
  show_numbers = true,
  show_cursorline = true,
  number_only = true,
}

local tracked_win_options = { "number", "cursorline", "foldenable" }

local function save_win_state(states, winnr)
  local win_options = {}
  for _, option in ipairs(tracked_win_options) do
    win_options[option] = vim.api.nvim_win_get_option(winnr, option)
  end
  states[winnr] = {
    cursor = vim.api.nvim_win_get_cursor(winnr),
    options = win_options,
  }
end

local function set_win_options(winnr, options)
  for option, value in pairs(options) do
    vim.api.nvim_win_set_option(winnr, option, value)
  end
end

local function peek(winnr, linenr)
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local n_buf_lines = vim.api.nvim_buf_line_count(bufnr)
  linenr = math.min(linenr, n_buf_lines)
  linenr = math.max(linenr, 1)

  -- Saving window state if this is a first call of peek()
  if not win_states[winnr] then
    save_win_state(win_states, winnr)
  end

  -- Set window options for peeking
  local peeking_options = {
    foldenable = false,
    number = opts.show_numbers and true or nil,
    cursorline = opts.show_cursorline and true or nil,
  }

  set_win_options(winnr, peeking_options)

  -- Setting the cursor
  local original_column = win_states[winnr].cursor[2]
  local peek_cursor = { linenr, original_column }
  vim.api.nvim_win_set_cursor(winnr, peek_cursor)
  pin_to_80_percent_height()
end

local function unpeek(winnr, stay)
  local orig_state = win_states[winnr]

  if not orig_state then
    return
  end

  -- Restoring original window options
  set_win_options(winnr, orig_state.options)

  if stay then
    -- Unfold at the cursorline if user wants to stay
    pin_to_80_percent_height()
  else
    -- Rollback the cursor if the user does not want to stay
    vim.api.nvim_win_set_cursor(winnr, orig_state.cursor)
  end
  win_states[winnr] = nil
end

local function is_peeking(winnr)
  return win_states[winnr] and true or false
end

function M.on_cmdline_changed()
  local cmd_line = vim.api.nvim_call_function("getcmdline", {})
  local winnr = vim.api.nvim_get_current_win()
  local num_str = cmd_line:match("^%d+" .. (opts.number_only and '$' or ''))
  if num_str then
    peek(winnr, tonumber(num_str))
    vim.cmd('redraw')
  elseif is_peeking(winnr) then
    unpeek(winnr, false)
    vim.cmd('redraw')
  end
end

function M.on_cmdline_exit()
  local winnr = vim.api.nvim_get_current_win()
  if not is_peeking(winnr) then
    return
  end

  local event = vim.api.nvim_get_vvar('event')
  local stay = not event.abort
  unpeek(winnr, stay)
end

function M.setup(user_opts)
  opts = vim.tbl_extend("force", opts, user_opts or {})
  vim.cmd[[
    augroup pinline
      autocmd!
      autocmd CmdlineChanged : lua require('pin-line').on_cmdline_changed()
      autocmd CmdlineLeave : lua require('pin-line').on_cmdline_exit()
    augroup END
  ]]
end

function M.disable()
  win_states = {}
  vim.cmd[[
    augroup pinline
      autocmd!
    augroup END
    augroup! pinline
  ]]
end

return M
