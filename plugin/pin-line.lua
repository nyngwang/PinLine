if vim.fn.has("nvim-0.5") == 0 then
  return
end

if vim.g.loaded_pin_line ~= nil then
  return
end

require('pin-line')

vim.g.loaded_pin_line = 1
