-- custom keymaps live here. LazyVim auto-loads this; leader keys are set in
-- init.lua before lazy.nvim bootstraps. add with `vim.keymap.set`.

local function run_current_file()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)

  if file == "" then
    vim.notify("No file to run (buffer has no name)", vim.log.levels.WARN, { title = "Runner" })
    return
  end

  -- Auto-format before running (Prettier for web/js/json/md, CSharpier for cs, clang-format for c/cpp, etc.)
  pcall(function()
    require("conform").format({ bufnr = buf, async = false, timeout_ms = 1000 })
  end)

  -- Auto-save before running
  if vim.bo[buf].modified then
    vim.cmd("silent! write")
  end

  local ext = vim.fn.fnamemodify(file, ":e"):lower()
  local stem = vim.fn.fnamemodify(file, ":t:r")
  local dir = vim.fn.fnamemodify(file, ":p:h")
  local ft = vim.bo[buf].filetype

  local cmd = nil

  if ft == "cpp" or ext == "cpp" or ext == "cc" or ext == "cxx" then
    cmd = string.format("g++ -std=c++20 -Wall -Wextra -O2 %q -o %q && %q", file, "/tmp/" .. stem, "/tmp/" .. stem)
  elseif ft == "c" or ext == "c" then
    cmd = string.format("gcc -Wall -Wextra -O2 %q -o %q && %q", file, "/tmp/" .. stem, "/tmp/" .. stem)
  elseif ft == "cs" or ext == "cs" then
    local root = vim.fs.root(file, function(name)
      return name:match("%.csproj$") or name:match("%.sln$")
    end)
    if root then
      cmd = string.format("cd %q && dotnet run", root)
    else
      cmd = string.format("cd %q && dotnet run %q", dir, file)
    end
  elseif ft == "java" or ext == "java" then
    cmd = string.format("javac %q && java -cp %q %q", file, dir, stem)
  elseif ft == "python" or ext == "py" then
    cmd = string.format("python3 %q", file)
  elseif ft == "html" or ext == "html" or ext == "htm" then
    cmd = string.format("xdg-open %q", file)
  elseif ft == "javascript" or ext == "js" then
    cmd = string.format("node %q", file)
  elseif ft == "typescript" or ext == "ts" then
    cmd = string.format("npx tsx %q", file)
  elseif ft == "rust" or ext == "rs" then
    local root = vim.fs.root(file, { "Cargo.toml" })
    if root then
      cmd = string.format("cd %q && cargo run", root)
    else
      cmd = string.format("rustc %q -o %q && %q", file, "/tmp/" .. stem, "/tmp/" .. stem)
    end
  elseif ft == "sh" or ft == "bash" or ext == "sh" or ext == "bash" then
    cmd = string.format("bash %q", file)
  else
    vim.notify("No runner configured for filetype: " .. ft, vim.log.levels.WARN, { title = "Runner" })
    return
  end

  local script = string.format(
    [[printf "\033[1;34m==> Running %s\033[0m\n\n"; %s; EXIT_CODE=$?; printf "\n\033[1;30m----------------------------------------\033[0m\n"; if [ $EXIT_CODE -eq 0 ]; then printf "\033[1;32m[Process completed successfully]\033[0m\n"; else printf "\033[1;31m[Process exited with code %s]\033[0m\n" "$EXIT_CODE"; fi; printf "\033[1;33mPress Enter to close...\033[0m"; read -r _]],
    vim.fn.fnamemodify(file, ":t"),
    cmd,
    "%d"
  )

  -- Pass array directly so fish shell doesn't try to parse bash variables ($?)
  local runner_cmd = { "bash", "-c", script }

  Snacks.terminal(runner_cmd, {
    cwd = dir,
    win = {
      position = "float",
      border = "rounded",
      width = 0.85,
      height = 0.8,
      backdrop = 60,
    },
    interactive = true,
  })
end

vim.keymap.set("n", "<F5>", run_current_file, { desc = "Compile & Run Current File" })
vim.keymap.set("n", "<leader>r", run_current_file, { desc = "Run Current File" })
