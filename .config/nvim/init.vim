" ===============================
"  Optixal-like Neovim Config
"  with pywal colors
" ===============================

" ----- Basics -----
set nocompatible
set encoding=utf-8
set number
set relativenumber
set cursorline
set hidden
set mouse=a
set clipboard=unnamedplus
set termguicolors

set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set splitbelow
set splitright
set laststatus=3      " global statusline
set signcolumn=yes

let mapleader=" "

" ----- pywal integration -----
if filereadable(expand("~/.cache/wal/colors-wal.vim"))
  source ~/.cache/wal/colors-wal.vim
endif

" ===============================
"  Plugins (vim-plug)
" ===============================
call plug#begin('~/.local/share/nvim/plugged')

" Core
Plug 'nvim-lua/plenary.nvim'

" Treesitter
Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }

" LSP + completion
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'L3MON4D3/LuaSnip'

" Telescope fuzzy finder
Plug 'nvim-telescope/telescope.nvim'

" File explorer
Plug 'nvim-tree/nvim-tree.lua'
Plug 'nvim-tree/nvim-web-devicons'

" Statusline
Plug 'nvim-lualine/lualine.nvim'

" Git signs
Plug 'lewis6991/gitsigns.nvim'

" Colorizer (optional, nice mit pywal)
Plug 'norcalli/nvim-colorizer.lua'

call plug#end()

" ===============================
"  General mappings
" ===============================
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :nohlsearch<CR>
nnoremap <leader>e :NvimTreeToggle<CR>
nnoremap <leader>f :Telescope find_files<CR>
nnoremap <leader>g :Telescope live_grep<CR>

" ===============================
"  Plugin configuration (Lua)
" ===============================
lua << EOF
-- Treesitter
local ok_ts, ts = pcall(require, 'nvim-treesitter.configs')
if ok_ts then
  ts.setup {
    ensure_installed = { 'lua', 'python', 'bash', 'json', 'yaml', 'markdown' },
    highlight = { enable = true },
    indent    = { enable = true },
  }
end

-- Lualine (Statusline) – Theme automatisch aus aktuellen Colors
local ok_ll, lualine = pcall(require, 'lualine')
if ok_ll then
  lualine.setup {
    options = {
      theme = 'auto',
      icons_enabled = true,
      globalstatus = true,
    },
  }
end

-- Nvim-tree
local ok_tree, nvim_tree = pcall(require, 'nvim-tree')
if ok_tree then
  nvim_tree.setup {
    view = { width = 30 },
    renderer = {
      highlight_git = true,
      highlight_opened_files = "all",
    },
    filters = { dotfiles = false },
  }
end

-- Telescope defaults
local ok_tel, telescope = pcall(require, 'telescope')
if ok_tel then
  telescope.setup {
    defaults = {
      mappings = {
        i = {
          ["<C-j>"] = "move_selection_next",
          ["<C-k>"] = "move_selection_previous",
        },
      },
    },
  }
end

-- Gitsigns
local ok_gs, gitsigns = pcall(require, 'gitsigns')
if ok_gs then
  gitsigns.setup()
end

-- Completion (nvim-cmp)
local ok_cmp, cmp = pcall(require, 'cmp')
if ok_cmp then
  local lspkind_ok, lspkind = pcall(require, 'lspkind')

  cmp.setup {
    formatting = lspkind_ok and {
      format = lspkind.cmp_format({ with_text = true, maxwidth = 50 }),
    } or nil,
    snippet = {
      expand = function(args)
        require('luasnip').lsp_expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<CR>']      = cmp.mapping.confirm({ select = true }),
      ['<C-j>']     = cmp.mapping.select_next_item(),
      ['<C-k>']     = cmp.mapping.select_prev_item(),
    }),
    sources = {
      { name = 'nvim_lsp' },
      { name = 'buffer' },
    },
  }
end

-- LSP (einfaches Setup)
local ok_lsp, lspconfig = pcall(require, 'lspconfig')
if ok_lsp then
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local cmp_lsp_ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
  if cmp_lsp_ok then
    capabilities = cmp_lsp.default_capabilities(capabilities)
  end

  local servers = { 'pyright', 'tsserver', 'bashls', 'jsonls' }
  for _, server in ipairs(servers) do
    lspconfig[server].setup {
      capabilities = capabilities,
    }
  end
end

-- Colorizer (nice mit pywal)
local ok_col, colorizer = pcall(require, 'colorizer')
if ok_col then
  colorizer.setup()
end
EOF
