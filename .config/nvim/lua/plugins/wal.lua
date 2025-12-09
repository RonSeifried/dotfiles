return {
  {
    "dylanaraps/wal.vim",
    lazy = false,
    priority = 1000,
    config = function()
      -- wal.vim Theme laden
      vim.cmd("colorscheme wal")

      -- LazyVim’s default apply_colors könnte Theme überschreiben → deaktivieren
      vim.g.lazyvim_colorscheme = "wal"
    end,
  },
}
