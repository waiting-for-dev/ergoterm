---Main module giving access to the terminal API

local FILETYPE = "ErgoTerm"

local M = {}

---@module "ergoterm.lazy"
local lazy = require("ergoterm.lazy")

---@module "ergoterm.config"
local config = lazy.require("ergoterm.config")
---@module "ergoterm.mode"
local mode = lazy.require("ergoterm.mode")
---@module "ergoterm.text_decorators"
local text_decorators = lazy.require("ergoterm.text_decorators")
---@module "ergoterm.text_selector"
local text_selector = lazy.require("ergoterm.text_selector")
---@module "ergoterm.utils"
local utils = lazy.require("ergoterm.utils")

---@class State
---@field last_focused Terminal? Last focused terminal
---@field last_focused_selectable Terminal? Last selectable focused terminal
---@field ids number[] All session terminal ids, even when deleted
---@field terminals Terminal[] All terminals
---@field universal_selection boolean Whether to ignore selectable flag in selection and last focused
M._state = {
  last_focused = nil,
  last_focused_selectable = nil,
  ids = {},
  terminals = {},
  universal_selection = false
}

---Returns the terminal that currently has window focus
---
---Searches through all terminals to find one whose window matches the current window.
---
---@return Terminal? the focused terminal, or nil if no terminal is focused
function M.get_focused()
  for _, term in pairs(M._state.terminals) do
    if term:is_focused() then return term end
  end
  return nil
end

---Returns the most recently focused terminal
---
---If `universal_selection` is enabled, returns the last focused terminal regardless
---of its `selectable` flag. Otherwise, returns the last focused terminal that is `selectable`.
---
---@return Terminal? the last focused terminal, or nil if none have been focused
function M.get_last_focused()
  if M._state.universal_selection then
    return M._state.last_focused
  else
    return M._state.last_focused_selectable
  end
end

---Returns all terminals in the current session
---
---Includes both started and stopped terminals. Use `filter()` to narrow results.
---
---@return Terminal[] array of all terminal instances
function M.get_all()
  local result = {}
  for _, v in pairs(M._state.terminals) do
    table.insert(result, v)
  end
  return result
end

---Retrieves a terminal by its unique identifier
---
---@param id number
---@return Terminal? the terminal with the given id, or nil if not found
function M.get(id)
  local term = M._state.terminals[id]
  return term
end

---Finds the first terminal with the specified name
---
---Names are not guaranteed to be unique, so this returns the first match found.
---
---@param name string
---@return Terminal? the first terminal with matching name, or nil if not found
function M.get_by_name(name)
  for _, term in pairs(M._state.terminals) do
    if term.name == name then return term end
  end
  return nil
end

---Finds the first terminal matching the given condition
---
---@param predicate fun(term: Terminal): boolean function that returns true for matching terminals
---@return Terminal? the first matching terminal, or nil if none match
function M.find(predicate)
  for _, term in pairs(M._state.terminals) do
    if predicate(term) then return term end
  end
  return nil
end

---Returns all terminals matching the given condition
---
---@param predicate fun(term: Terminal): boolean function that returns true for matching terminals
---@return Terminal[] array of all matching terminals
function M.filter(predicate)
  local result = {}
  for _, term in pairs(M._state.terminals) do
    if predicate(term) then
      table.insert(result, term)
    end
  end
  return result
end

---Presents a picker interface for terminal selection
---
---Only shows started terminals with `selectable=true`, unless universal_selection is enabled.
---If universal_selection is true, shows all started terminals regardless of selectable flag.
---If no terminals are available, displays an info notification instead of opening the picker.
---
---@param picker Picker the picker implementation to use
---@param prompt string text to display in the picker
---@param callbacks table<string, PickerCallbackDefinition> actions to execute on terminal selection
---@return any result from the picker, or nil if no terminals available
function M.select(picker, prompt, callbacks)
  local terminals = M.filter(function(term)
    ---@diagnostic disable-next-line: return-type-mismatch
    return term:is_started() and (M._state.universal_selection or term.selectable)
  end)
  if #terminals == 0 then return utils.notify("No ergoterms have been started yet", "info") end
  return picker.select(terminals, prompt, callbacks)
end

---Removes all terminals from the session
---
---Automatically closes windows and stops jobs for all terminals before deletion.
---This is a destructive operation that cannot be undone.
function M.delete_all()
  local terminals = M.get_all()
  for _, term in ipairs(terminals) do
    term:delete()
  end
end

---Accesses internal module state
---
---Primarily used for debugging and testing.
---
---@param key string
---@return any the state value for the given key
function M.get_state(key)
  return M._state[key]
end

---Toggles universal selection mode
---
---When universal selection is enabled, all terminals are shown in pickers and
---can be set as last focused, regardless of their selectable flag. This provides
---a temporary override for the selectable setting.
---
---@return boolean the new state of universal_selection after toggling
function M.toggle_universal_selection()
  M._state.universal_selection = not M._state.universal_selection
  return M._state.universal_selection
end

---Resets the terminal ID sequence back to 1
---
---Terminal IDs are normally never reused, even after deletion. This function
---clears the ID history, allowing the sequence to restart from 1. Useful for
---testing.
function M.reset_ids()
  M._state.ids = {}
end

---@class ComputedSizeOpts
---@field below number
---@field above number
---@field left number
---@field right number

---@class TerminalState
---@field bufnr number?
---@field dir? string
---@field layout layout
---@field float_opts FloatOpts
---@field mode Mode
---@field job_id? number
---@field on_job_exit on_job_exit
---@field on_job_stdout on_job_stdout
---@field on_job_stderr on_job_stderr
---@field size ComputedSizeOpts
---@field tabpage number?
---@field window number?

---@class TermCreateArgs
---@field auto_scroll boolean? whether or not to scroll down on terminal output
---@field cmd? string command to run in the terminal
---@field clear_env? boolean use clean job environment, passed to jobstart()
---@field close_on_job_exit boolean? whether or not to close the terminal window when the process exits
---@field dir string? the directory for the terminal
---@field layout layout? the layout to open the terminal in the first time
---@field env? table<string, string> environmental variables passed to jobstart()
---@field name string?
---@field float_opts FloatOpts? options for the floating window
---@field float_winblend? number
---@field on_close on_close? Callback to run when the terminal is closed. It takes the terminal as an argument.
---@field on_create on_create? Callback to run when the terminal is created. It takes the terminal as an argument.
---@field on_focus on_focus? Callback to run when the terminal is focused. It takes the terminal as an argument.
---@field on_job_exit on_job_exit? Callback to run when the
---@field on_job_stderr on_job_stderr?
---@field on_job_stdout on_job_stdout?
---@field on_open on_open?
---@field on_stop on_stop?
---@field on_start on_start?
---@field persist_mode boolean? whether or not to persist the mode of the terminal on return
---@field selectable boolean? whether or not the terminal is visible in picker selections and can be last focused
---@field size SizeOpts? size configuration for different layouts
---@field start_in_insert boolean?

---@class Terminal : TermCreateArgs
---@field id number
---@field _state TerminalState
local Terminal = {}
Terminal.__index = Terminal

---Creates a new terminal instance with merged configuration
---
---Combines provided arguments with global configuration defaults. The terminal
---is registered in the module state but not started until `start()` is called.
---
---@param args TermCreateArgs?
---@return Terminal the newly created terminal instance
function Terminal:new(args)
  local term = args or {} ---@cast term Terminal
  setmetatable(term, self)
  term.auto_scroll = vim.F.if_nil(term.auto_scroll, config.get("terminal_defaults.auto_scroll"))
  term.cmd = term.cmd or config.get("terminal_defaults.shell")
  term.clear_env = vim.F.if_nil(term.clear_env, config.get("terminal_defaults.clear_env"))
  term.close_on_job_exit = vim.F.if_nil(term.close_on_job_exit, config.get("terminal_defaults.close_on_job_exit"))
  term.layout = term.layout or config.get("terminal_defaults.layout")
  term.env = term.env
  term.name = term.name or term.cmd
  term.float_opts = vim.tbl_deep_extend("keep", term.float_opts or {}, config.get("terminal_defaults.float_opts")) --@type FloatOpts
  term.float_winblend = term.float_winblend or config.get("terminal_defaults.float_winblend")
  term.persist_mode = vim.F.if_nil(term.persist_mode, config.get("terminal_defaults.persist_mode"))
  term.selectable = vim.F.if_nil(term.selectable, config.get("terminal_defaults.selectable"))
  term.size = vim.tbl_deep_extend("keep", term.size or {}, config.get("terminal_defaults.size")) --@type SizeOpts
  term.start_in_insert = vim.F.if_nil(term.start_in_insert, config.get("terminal_defaults.start_in_insert"))
  term.on_close = vim.F.if_nil(term.on_close, config.get("terminal_defaults.on_close"))
  term.on_create = vim.F.if_nil(term.on_create, config.get("terminal_defaults.on_create"))
  term.on_focus = vim.F.if_nil(term.on_focus, config.get("terminal_defaults.on_focus"))
  term.on_job_stderr = vim.F.if_nil(term.on_job_stderr, config.get("terminal_defaults.on_job_stderr"))
  term.on_job_stdout = vim.F.if_nil(term.on_job_stdout, config.get("terminal_defaults.on_job_stdout"))
  term.on_job_exit = vim.F.if_nil(term.on_job_exit, config.get("terminal_defaults.on_job_exit"))
  term.on_open = vim.F.if_nil(term.on_open, config.get("terminal_defaults.on_open"))
  term.on_start = vim.F.if_nil(term.on_start, config.get("terminal_defaults.on_start"))
  term.on_stop = vim.F.if_nil(term.on_stop, config.get("terminal_defaults.on_stop"))
  term.id = M._compute_id()
  term:_initialize_state()
  term:_add_to_state()
  return term
end

---Updates terminal configuration after creation
---
---Most options can be changed, but 'cmd' and 'dir' are immutable after creation.
---Float and size options are merged with existing values rather than replaced entirely.
---
---@param opts TermCreateArgs configuration changes to apply
---@return Terminal? self for method chaining, or nil on error
function Terminal:update(opts)
  for _, key in ipairs({ "float_opts", "size" }) do
    if opts[key] then
      self[key] = vim.tbl_deep_extend("keep", opts[key], self[key])
      opts[key] = nil
    end
  end
  for k, v in pairs(opts) do
    if k == "cmd" or k == "dir" then
      utils.notify(
        string.format("Cannot change %s after terminal creation", k),
        "error"
      )
    else
      self[k] = v
    end
  end
  self:_recompute_state()
  return self
end

---Initializes the terminal job and buffer
---
---Creates the terminal buffer and starts the underlying job process. Does not
---open a window - use `open()` or `focus()` for that. Idempotent - safe to call
---multiple times. Triggers the `on_create` callback.
---
---@return self for method chaining
function Terminal:start()
  if not self:is_started() then
    self._state.dir = self:_compute_dir()
    self._state.bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_call(self._state.bufnr, function()
      self._state.job_id = self:_start_job()
    end)
    self:_setup_buffer_autocommands()
    self:on_create()
  end
  return self
end

---Checks if the terminal job is running
---
---A started terminal has an active buffer and job process, but may not have
---a visible window.
---
---@return boolean true if the terminal job is active
function Terminal:is_started()
  return self._state.bufnr ~= nil and vim.api.nvim_buf_is_valid(self._state.bufnr)
end

---Creates a window for the terminal without focusing it
---
---Automatically starts the terminal if not already started. Uses the provided
---layout or falls back to the terminal's current layout setting. The layout
---determines window positioning:
---
---• "above" - horizontal split above current window
---• "below" - horizontal split below current window
---• "left" - vertical split to the left
---• "right" - vertical split to the right
---• "tab" - new tab page
---• "float" - floating window with configured dimensions
---• "window" - replace current window content
---
---Idempotent - safe to call on already open terminals.
---
---@param layout string? window layout override
---@return self for method chaining
function Terminal:open(layout)
  if not self:is_started() then self:start() end
  if not self:is_open() then
    local current_win = vim.api.nvim_get_current_win()
    local computed_layout = layout or self._state.layout
    if computed_layout == "above" then
      vim.cmd(self._state.size.above .. "split")
    elseif computed_layout == "below" then
      vim.cmd("botright " .. self._state.size.below .. "split")
    elseif computed_layout == "left" then
      vim.cmd(self._state.size.left .. "vsplit")
    elseif computed_layout == "right" then
      vim.cmd("botright " .. self._state.size.right .. "vsplit")
    elseif computed_layout == "tab" then
      vim.cmd("tabnew")
      vim.bo.bufhidden = "wipe"
    elseif computed_layout == "float" then
      vim.api.nvim_open_win(self._state.bufnr, true, self._state.float_opts)
    end
    self._state.layout = computed_layout
    self._state.window = vim.api.nvim_get_current_win()
    self._state.tabpage = vim.api.nvim_get_current_tabpage()
    vim.api.nvim_win_set_buf(self._state.window, self._state.bufnr)
    self:_set_options()
    self:on_open()
    vim.api.nvim_set_current_win(current_win)
  end
  return self
end

---Checks if the terminal has a visible window
---
---Searches all tabpages to determine if the terminal's window still exists
---and is valid.
---
---@return boolean true if the terminal window is currently visible
function Terminal:is_open()
  if not self._state.window then return false end
  local wins = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    vim.list_extend(wins, vim.api.nvim_tabpage_list_wins(tab))
  end
  return vim.tbl_contains(wins, self._state.window)
end

---Closes the terminal window while keeping the job running
---
---The terminal can be reopened later with `open()` or `focus()`. Triggers the
---`on_close` callback. No-op if the terminal is not currently open.
---
---@return Terminal self for method chaining
function Terminal:close()
  if self:is_open() then
    self:on_close()
    vim.api.nvim_win_close(self._state.window, true)
  end
  return self
end

---Brings the terminal window into focus and switches to it
---
---Automatically starts and opens the terminal if needed. Switches to the
---terminal's tabpage and window, making it the active window. Sets up the
---appropriate terminal mode and triggers the `on_focus` callback.
---
---@param layout string? window layout to use if opening for the first time
---@return self for method chaining
function Terminal:focus(layout)
  if not self:is_open() then self:open(layout) end
  if not self:is_focused() then
    vim.api.nvim_set_current_tabpage(self._state.tabpage)
    vim.api.nvim_set_current_win(self._state.window)
    self:_set_last_focused()
    self:_set_return_mode()
    self:on_focus()
  end
  return self
end

---Checks if this terminal is the currently active window
---
---@return boolean true if this terminal's window is the current window
function Terminal:is_focused()
  return self._state.window == vim.api.nvim_get_current_win()
end

---Terminates the terminal job and cleans up resources
---
---Stops the underlying job process, deletes the buffer, and optionally closes any open
---windows. Triggers the `on_stop` callback. The terminal can be restarted
---later with `start()`.
---
---@param with_close? boolean whether to close the terminal window (default: true)
---@return Terminal self for method chaining
function Terminal:stop(with_close)
  with_close = vim.F.if_nil(with_close, true)
  if with_close and self:is_open() then self:close() end
  if self:is_started() then
    self:on_stop()
    vim.fn.jobstop(self._state.job_id)
    self._state.job_id = nil
    if self._state.bufnr then
      self._state.bufnr = nil
    end
  end
  return self
end

---Checks if the terminal job has been terminated
---
---@return boolean true if no job is currently running
function Terminal:is_stopped()
  return self._state.job_id == nil
end

---Permanently removes the terminal from the session
---
---Stops the terminal if running and removes it from the module's terminal
---registry. This is irreversible - the terminal instance becomes unusable
---after deletion.
---
---@param with_close? boolean whether to close the terminal window when stopping (default: true)
function Terminal:delete(with_close)
  if not self:is_stopped() then
    self:stop(with_close)
  end
  if M._state.last_focused == self then
    M._state.last_focused = nil
  end
  if M._state.last_focused_selectable == self then
    M._state.last_focused_selectable = nil
  end
  M._state.terminals[self.id] = nil
end

---Toggles terminal window visibility
---
---Closes the terminal if currently open, or focuses it if closed. Provides
---a convenient way to show/hide terminals with a single command.
---
---@param layout string? window layout to use when opening
---@return Terminal self for method chaining
function Terminal:toggle(layout)
  if self:is_open() then
    self:close()
  else
    self:focus(layout)
  end
  return self
end

---@class SendOptions
---@field action? "interactive"|"visible"|"silent" terminal interaction mode (default: "interactive")
---@field trim? boolean remove leading/trailing whitespace (default: true)
---@field new_line? boolean append newline for command execution (default: true)
---@field decorator? fun(text: string[]): string[]|string transform text before sending

---Sends text input to the terminal job
---
---Automatically starts the terminal if not running. The opts.action parameter controls
---window behavior: "interactive" focuses the terminal for user interaction,
---"visible" shows output without stealing focus, "silent" sends without UI changes.
---Text is trimmed by default and gets a trailing newline for command execution.
---
---Input can be provided as:
---• Array of strings - sends the text directly
---• "single_line" - sends the current line under cursor
---• "visual_lines" - sends the current visual line selection
---• "visual_selection" - sends the current visual character selection
---
---@param input string[]|"single_line"|"visual_lines"|"visual_selection" lines of text to send or selection type
---@param opts? SendOptions options for sending text
---@return self for method chaining
function Terminal:send(input, opts)
  opts = opts or {}
  local computed_action = opts.action or "interactive"
  local computed_trim = opts.trim == nil or opts.trim
  local computed_new_line = opts.new_line == nil or opts.new_line
  local computed_decorator
  if type(opts.decorator) == "string" then
    computed_decorator = text_decorators[opts.decorator] or text_decorators.identity
  else
    computed_decorator = opts.decorator or text_decorators.identity
  end
  local caller_window = vim.api.nvim_get_current_win()
  local text_input
  if type(input) == "string" then
    local valid_selection_types = { "single_line", "visual_lines", "visual_selection" }
    if not vim.tbl_contains(valid_selection_types, input) then
      utils.notify(
        string.format("Invalid input type '%s'. Must be a table with one item per line or one of: %s", input,
          table.concat(valid_selection_types, ", ")),
        "error"
      )
      return self
    end
    text_input = text_selector.select(input)
  else
    text_input = input
  end
  if computed_new_line then
    table.insert(text_input, "")
  end
  if computed_trim then
    for i, line in ipairs(text_input) do
      text_input[i] = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
  end
  local decorated_input = computed_decorator(text_input)
  vim.fn.chansend(self._state.job_id, decorated_input)
  self:_scroll_bottom()
  if computed_action ~= "silent" and not self:is_open() then
    self:open()
  end
  if computed_action == "interactive" then
    self:focus()
  else
    vim.schedule(function()
      vim.api.nvim_set_current_win(caller_window)
    end)
  end
  return self
end

---Clears the terminal display
---
---Sends the appropriate clear command for the current platform (`cls` on Windows,
---`clear` on Unix systems). Opens and focuses the terminal to show the result.
function Terminal:clear()
  local clear = utils.is_windows() and "cls" or "clear"
  self:send({ clear })
end

---Handles buffer enter events for the terminal
---
---Sets up filetype-specific options and restores the appropriate terminal mode.
---Called automatically when entering the terminal buffer.
function Terminal:on_buf_enter()
  self:_set_ft_options()
  self:_set_return_mode()
end

---Handles window enter events for the terminal
---
---Sets the last focused terminal to this instance if universal selection is enabled
---or if the terminal is selectable.
function Terminal:on_win_enter()
  self:_set_last_focused()
end

---Handles window leave events for the terminal
---
---Saves the current mode if persist_mode is enabled, and automatically closes
---floating terminals when focus is lost to prevent them from lingering.
function Terminal:on_win_leave()
  if self.persist_mode then self:_persist_mode() end
  if self._state.layout == "float" then self:close() end
end

---Handles terminal close events
---
---Automatically deletes the terminal instance when the underlying terminal
---process exits.
---
---Respects the `close_on_job_exit` setting to determine whether
---to close the terminal window.
function Terminal:on_term_close()
  vim.schedule(function() self:delete(self.close_on_job_exit) end)
end

---Accesses internal terminal state
---
---Primarily used for debugging and testing.
---
---@param key string
---@return any the state value for the given key
function Terminal:get_state(key)
  return self._state[key]
end

---@private
function Terminal:_set_ft_options()
  local buf = vim.bo[self._state.bufnr]
  buf.filetype = FILETYPE
  buf.buflisted = false
  buf.bufhidden = "hide"
end

---@private
function Terminal:_set_win_options()
  vim.api.nvim_set_option_value("number", false, { scope = "local", win = self._state.window })
  vim.api.nvim_set_option_value("signcolumn", "no", { scope = "local", win = self._state.window })
  vim.api.nvim_set_option_value("relativenumber", false, { scope = "local", win = self._state.window })
  if self._state.layout == "float" then
    self:_set_float_options()
  end
end

---@private
function Terminal:_set_options()
  self:_set_ft_options()
  self:_set_win_options()
end

---@private
function M._compute_id()
  return #M._state.ids + 1
end

---@private
function Terminal:_add_to_state()
  table.insert(M._state.ids, self.id)
  M._state.terminals[self.id] = self
end

---@private
function Terminal:_compute_exit_handler(callback)
  return function(job, exit_code, event)
    callback(self, job, exit_code, event)
  end
end

---@private
function Terminal:_compute_output_handler(callback)
  return function(channel_id, data, name)
    if self.auto_scroll then self:_scroll_bottom() end
    callback(self, channel_id, data, name)
  end
end

---@private
function Terminal:_initialize_state()
  self._state = {
    bufnr = nil,
    dir = self:_compute_dir(),
    layout = self.layout,
    float_opts = self:_compute_float_opts(),
    job_id = nil,
    mode = mode.get_initial(self.start_in_insert),
    on_job_exit = self:_compute_exit_handler(self.on_job_exit),
    on_job_stdout = self:_compute_output_handler(self.on_job_stdout),
    on_job_stderr = self:_compute_output_handler(self.on_job_stderr),
    size = self:_compute_size(),
    tabpage = nil,
    window = nil
  }
end

function Terminal:_recompute_state()
  self._state.mode = mode.get_initial(self.start_in_insert)
  self._state.layout = self.layout
  self._state.on_job_exit = self:_compute_exit_handler(self.on_job_exit)
  self._state.on_job_stdout = self:_compute_output_handler(self.on_job_stdout)
  self._state.on_job_stderr = self:_compute_output_handler(self.on_job_stderr)
  self._state.size = self:_compute_size()
end

---@private
function Terminal:_compute_dir()
  local dir = nil
  if self.dir == "git_dir" then
    dir = utils.git_dir()
  elseif self.dir == nil then
    dir = vim.loop.cwd()
  else
    dir = vim.fn.expand(self.dir)
    if vim.fn.isdirectory(dir) == 0 then
      utils.notify(
        string.format("%s is not a directory", dir),
        "error"
      )
    end
  end
  return dir
end

---@private
function Terminal:_compute_float_opts()
  local float_opts = self.float_opts or {}
  float_opts.title = float_opts.title or self.name
  float_opts.row = float_opts.row or math.ceil(vim.o.lines - float_opts.height) * 0.5 - 1
  float_opts.col = float_opts.col or math.ceil(vim.o.columns - float_opts.width) * 0.5 - 1
  return float_opts
end

---@private
function Terminal:_compute_size()
  local size = {}
  for direction, value in pairs(self.size) do
    if type(value) == "string" and value:match("%%$") then
      local percentage = tonumber(value:match("(%d+)%%"))
      if direction == "below" or direction == "above" then
        size[direction] = math.ceil(vim.o.lines * percentage / 100)
      else
        size[direction] = math.ceil(vim.o.columns * percentage / 100)
      end
    else
      size[direction] = value
    end
  end
  return size
end

---@private
function Terminal:_start_job()
  return vim.fn.termopen(self.cmd, {
    detach = 1,
    cwd = self._state.dir,
    on_exit = self._state.on_job_exit,
    on_stdout = self._state.on_job_stdout,
    on_stderr = self._state.on_job_stderr,
    env = self.env,
    clear_env = self.clear_env,
  })
end

---@private
function Terminal:_restore_mode()
  mode.set(self._state.mode)
  return self
end

---@private
function Terminal:_set_last_focused()
  M._state.last_focused = self
  if self.selectable then
    M._state.last_focused_selectable = self
  end
  return self
end

---@private
function Terminal:_set_return_mode()
  if self.persist_mode then
    self:_restore_mode()
  else
    self:_set_initial_mode()
  end
  return self
end

---@private
function Terminal:_persist_mode()
  self._state.mode = mode.get()
  return self
end

---@private
function Terminal:_set_initial_mode()
  mode.set_initial(self.start_in_insert)
  return self
end

---Sets the floating terminal options
function Terminal:_set_float_options()
  vim.api.nvim_set_option_value("sidescrolloff", 0, { scope = "local", win = self._state.window })
  vim.api.nvim_set_option_value("winblend", self.float_winblend, { scope = "local", win = self._state.window })
end

function Terminal:_setup_buffer_autocommands()
  local group = vim.api.nvim_create_augroup("ErgoTermBuffer", { clear = true })
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = self._state.bufnr,
    group = group,
    callback = function() self:on_term_close() end
  })
end

---@private
function Terminal:_scroll_bottom()
  if self:is_open() then
    vim.api.nvim_buf_call(self._state.bufnr, function()
      if mode.get() == mode.NORMAL then
        vim.cmd("normal! G")
      end
    end)
  end
end

M.Terminal = Terminal

return M
