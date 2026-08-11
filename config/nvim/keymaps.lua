-- Personal Neovim keymaps

vim.g.mapleader = " "

-- File explorer
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Move selected lines vertically in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Keep cursor position when joining lines
vim.keymap.set("n", "J", "mzJ`z")

-- Keep cursor centered while scrolling
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- Keep search results centered
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Paste without replacing yank buffer
vim.keymap.set("x", "<leader>p", '"_dP')

-- Yank to system clipboard
vim.keymap.set("n", "<leader>y", '"+y')
vim.keymap.set("v", "<leader>y", '"+y')
vim.keymap.set("n", "<leader>Y", '"+Y')

-- Exit insert mode
vim.keymap.set("i", "jk", "<Esc>")

-- Save file
vim.keymap.set("n", "<Esc>", "<cmd>w<CR>")

-- Make current file executable
vim.keymap.set(
  "n",
  "<leader>x",
  "<cmd>!chmod +x %<CR>",
  { silent = true }
)

-- Add # to the beginning of selected lines
vim.keymap.set(
  "v",
  "<leader>c",
  ":s/^/#/<CR>gv",
  { silent = true }
)

-- Window navigation
vim.keymap.set("n", "<C-k>", "<cmd>wincmd k<CR>")
vim.keymap.set("n", "<C-j>", "<cmd>wincmd j<CR>")
vim.keymap.set("n", "<C-h>", "<cmd>wincmd h<CR>")
vim.keymap.set("n", "<C-l>", "<cmd>wincmd l<CR>")

-- Copy to system clipboard with Ctrl+C
vim.keymap.set(
  "v",
  "<C-c>",
  '"+y',
  { noremap = true, silent = true }
)

-- Paste from system clipboard with Ctrl+V
vim.keymap.set(
  "n",
  "<C-v>",
  '"+p',
  { noremap = true, silent = true }
)
