return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- This line from your original config is likely what's causing the deprecation warning.
      -- It's okay to leave it, but updating your NvChad/Neovim distribution will likely fix it.
      require "configs.lspconfig"

      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      
      -- We still need nvim-lspconfig's 'util' for the root_dir function
      local lspconfig_util = require("lspconfig.util")

      -- OmniSharp setup for C#
      -- This is the NEW way to configure LSPs (Neovim 0.11+)
      vim.lsp.config("omnisharp", {
        capabilities = capabilities,
        cmd = { "omnisharp" },
        enable_roslyn_analyzers = true, -- Enable .editorconfig support
        enable_import_completion = true,
        organize_imports_on_format = true,
        enable_decompilation_support = true,
        analyze_open_documents_only = false, -- Analyze entire project
        filetypes = { "cs", "vb" },
        settings = {
          FormattingOptions = {
            EnableEditorConfigSupport = true,
            OrganizeImports = true,
          },
          RoslynExtensionsOptions = {
            EnableAnalyzersSupport = true,
            EnableImportCompletion = true,
            AnalyzeOpenDocumentsOnly = false,
          },
        },
        root_dir = function(fname)
          -- Use the 'lspconfig_util' we required above
          return lspconfig_util.root_pattern("*.sln")(fname)
            or lspconfig_util.root_pattern("*.csproj")(fname)
            or lspconfig_util.root_pattern(".git")(fname)
        end,
        -- 'on_attach' is now handled by the global autocommand below
      })
      
      -- After configuring, you must enable the server
      vim.lsp.enable("omnisharp")


      -- This is the NEW way to set keymaps for LSPs.
      -- This 'LspAttach' event will run for *every* language server that starts.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspConfig', {}),
        callback = function(ev)
          -- ev.buf is the buffer number that the LSP attached to
          local opts = { noremap = true, silent = true, buffer = ev.buf }
          
          -- Key mappings
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, opts)
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
          vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
        end,
      })

      -- Diagnostic configuration (your original code was correct)
      vim.diagnostic.config({
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
          -- Show diagnostics in insert mode
          severity = {
            min = vim.diagnostic.severity.HINT,
          },
        },
        signs = true,
        update_in_insert = true, -- Update diagnostics in insert mode
        underline = true,
        severity_sort = true,
        float = {
          border = "rounded",
          source = "always",
          header = "",
          prefix = "",
        },
      })

      -- Diagnostic signs (your original code was correct)
      local signs = { Error = "󰅚 ", Warn = "󰀪 ", Hint = "󰌶 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end
    end,
  },

  {
    "editorconfig/editorconfig-vim",
    lazy = false
  }

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   opts = {
  --     ensure_installed = {
  --       "vim", "lua", "vimdoc",
  --       "html", "css"
  --     },
  --   },
  -- },
}
