-- Simplest possible capture: save every line that appears in terminal
local M = {}
local debug = require("terminal-history.debug")

-- Состояния процесса
local STATES = {
  WAITING_FOR_COMMAND = 1, -- Ждём ввод команды
  COMMAND_ENTERED = 2, -- Enter нажат, команда введена
  EXECUTING = 3, -- Команда выполняется
  WAITING_FOR_PROMPT = 4, -- Ждём новый prompt
}

M.terminals = {}

-- Проверяет, похожа ли строка на prompt (с поддержкой многострочных)
function M.is_prompt_like(lines, index)
  local line = lines[index]
  if not line or line == "" then
    return false, false -- is_prompt, is_multiline
  end

  -- Паттерны для однострочных prompt'ов
  local single_patterns = {
    "[$#>%%]%s*$", -- Классические $ # > %
    "^%S+@%S+:", -- user@host:
    "^%(.*%)%s*[$#>]", -- (venv) $
    "^%[.*%]%s*[$#>]", -- [docker] $
    "^root@", -- root в контейнере
    "^docker>", -- Docker prompt
  }

  for _, pattern in ipairs(single_patterns) do
    if line:match(pattern) then
      return true, false -- is_prompt, is_multiline
    end
  end

  -- Проверяем на символ промпта для многострочного варианта
  local prompt_symbols = { "^➜%s*$", "^❯%s*$", "^▶%s*$", "^λ%s*$", "^>>>%s*$" }
  local is_prompt_symbol = false

  for _, pattern in ipairs(prompt_symbols) do
    if line:match(pattern) then
      is_prompt_symbol = true
      break
    end
  end

  -- Если это символ промпта, проверяем предыдущую строку
  if is_prompt_symbol and index > 1 then
    local prev_line = lines[index - 1]

    -- Признаки информационной строки (первая строка многострочного промпта)
    if prev_line and #prev_line > 15 then
      local is_info_line = prev_line:match("[~/]") -- путь
        or prev_line:match("[⇡⇣±]") -- git символы
        or prev_line:match("master") -- git branch
        or prev_line:match("main") -- git branch
        or prev_line:match("%d+:%d+") -- время
        or prev_line:match("%(.*%)") -- скобки с информацией
        or prev_line:match("via") -- via (версия)
        or prev_line:match("on") -- on (ветка)

      if is_info_line then
        return true, true -- is_prompt, is_multiline
      end
    end

    -- Если предыдущая строка пустая, возможно это тоже промпт
    if prev_line == "" and #line <= 5 then
      return true, false
    end
  end

  -- Дополнительная эвристика для коротких строк
  if #line < 80 and not is_prompt_symbol then
    -- Проверяем, не является ли это просто короткой командой
    local might_be_prompt = line:match("[#$>%%]%s*$") or line:match("^%S+@%S+")
    return might_be_prompt or false, false
  end

  return false, false
end

-- Функция мониторинга буферов
function M.monitor_buffer_changes(_, bufnr, _, first_line, _, last_line_new, _)

  local state = M.terminals[bufnr]
  if not state then
    return
  end

  state.known_prompts = state.known_prompts or {}

  -- Детектируем prompt только в состоянии ожидания
  if state.state == STATES.WAITING_FOR_PROMPT and last_line_new > 0 then
    local lines = vim.api.nvim_buf_get_lines(bufnr, math.max(0, first_line), last_line_new, false)

    -- Идём с конца массива строк
    for i = #lines, 1, -1 do
      local line = lines[i]
      local line_number = first_line + i - 1 -- Вычисляем абсолютный номер строки

      -- Пропускаем пустые строки и строки до предыдущего промпта
      if line_number > (state.current_prompt_line or -1) then
        local prompt_found = false
        local is_multiline = false

        -- Проверяем на промпт (с поддержкой многострочных)
        local is_prompt, multiline = M.is_prompt_like(lines, i)

        if is_prompt then
          if multiline then
            -- Многострочный промпт
            local prev_line = lines[i - 1] or ""
            local prompt_key = prev_line .. "\n" .. line

            if not vim.tbl_contains(state.known_prompts, prompt_key) then
              table.insert(state.known_prompts, prompt_key)
            else
            end

            is_multiline = true
          else
            -- Однострочный промпт
            if not vim.tbl_contains(state.known_prompts, line) then
              table.insert(state.known_prompts, line)
            else
            end
          end

          prompt_found = true
        end

        if prompt_found then
          -- Захватываем вывод команды перед обновлением промпта
          if state.current_command and state.current_command.output_start_line then
            -- Для многострочного промпта: учитываем, что информационная строка исчезла
            local output_start_adjusted = state.current_command.output_start_line - 1

            -- Если промпт был многострочным, строки сдвинулись вверх на 1
            if state.current_command.prompt_is_multiline then
              output_start_adjusted = output_start_adjusted - 1
            end

            local output_lines = vim.api.nvim_buf_get_lines(
              bufnr,
              output_start_adjusted, -- 0-based, с учётом сдвига
              line_number - 1, -- не включая новый промпт
              false
            )

            -- Сохраняем полную запись
            local entry = {
              id = os.time() * 1000 + math.random(1000),
              terminal_id = state.term_id,
              command = state.current_command.text,
              command_lines = state.current_command.lines,
              output = table.concat(output_lines, "\n"),
              output_lines = output_lines,
              prompt_line = state.current_command.prompt_line,
              enter_line = state.current_command.enter_line,
              output_end_line = line_number - 1,
              timestamp = state.current_command.timestamp,
              cwd = vim.fn.getcwd(),
            }

            -- Сохраняем в историю
            local core = require("terminal-history.core")
            core.add_to_history(state.term_id, entry)


            -- Очищаем текущую команду
            state.current_command = nil
          end

          -- Обновляем промпт и состояние
          if is_multiline then
            -- Сохраняем информацию о многострочном промпте
            state.current_prompt_info = {
              lines = { lines[i - 1], line },
              start_line = line_number - 1,
              end_line = line_number,
              is_multiline = true,
            }
            state.current_prompt = line -- Сохраняем символ промпта для обратной совместимости
            state.current_prompt_line = line_number - 1 -- Начало многострочного промпта
          else
            -- Однострочный промпт
            state.current_prompt_info = {
              lines = { line },
              start_line = line_number,
              end_line = line_number,
              is_multiline = false,
            }
            state.current_prompt = line
            state.current_prompt_line = line_number
          end

          state.state = STATES.WAITING_FOR_COMMAND
          break
        end
      end
    end
  end

  -- Вызываем существующий обработчик
  -- M.on_lines_changed(bufnr)
end

-- Setup line-by-line capture
function M.setup(bufnr)
  local core = require("terminal-history.core")
  local term_id = core.get_terminal_id(bufnr)
  if not term_id then
    return
  end

  local terminal = core.get_terminal(term_id)
  if not terminal then
    return
  end


  -- State for this terminal
  M.terminals[bufnr] = {
    term_id = term_id,
    last_line_count = 0,
    pending_command = nil,
    known_prompts = {}, -- Список всех известных промптов (включая многострочные)
    current_prompt = nil, -- Текущий активный промпт (для обратной совместимости)
    current_prompt_line = nil, -- Номер строки с последним промптом
    current_prompt_info = nil, -- Полная информация о текущем промпте (включая многострочные)
    state = STATES.WAITING_FOR_PROMPT, -- Начальное состояние - ждём первый промпт
    current_command = nil, -- Текущая выполняемая команда с полной информацией
  }

  -- Monitor buffer changes
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = M.monitor_buffer_changes,
  })

  -- Also intercept Enter to mark command boundaries
  vim.keymap.set(
    "t",
    "<CR>",
    function()
      -- Mark that Enter was pressed
      M.on_enter_pressed(bufnr)
      -- Send Enter to terminal
      vim.api.nvim_feedkeys("\r", "n", false)
    end,
    {
      buffer = bufnr,
      silent = true,
      noremap = true
    }
  )
end

-- Called when Enter is pressed
function M.on_enter_pressed(bufnr)
  local state = M.terminals[bufnr]
  if not state then
    return
  end

  -- Получаем все строки буфера
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Находим позицию курсора (где нажат Enter)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Захватываем команду от промпта до курсора
  if state.current_prompt_info then
    local command_lines = {}
    local command_start_line = state.current_prompt_info.end_line -- После промпта

    -- Для многострочного промпта команда начинается со следующей строки после символа промпта
    -- Для однострочного - с той же строки после текста промпта
    if state.current_prompt_info.is_multiline then
      -- Многострочный промпт: команда на той же строке, что и символ промпта
      command_start_line = state.current_prompt_info.end_line
    else
      -- Однострочный промпт: команда на той же строке
      command_start_line = state.current_prompt_info.start_line
    end

    for i = command_start_line, cursor_line do
      local line = all_lines[i + 1] or ""

      -- Обработка первой строки команды
      if i == command_start_line then
        if state.current_prompt_info.is_multiline then
          -- Для многострочного промпта: убираем символ промпта из строки
          local prompt_symbol = state.current_prompt_info.lines[2] or state.current_prompt
          local prompt_end = line:find(vim.pesc(prompt_symbol), 1, true)
          if prompt_end then
            line = line:sub(prompt_end + #prompt_symbol)
            line = line:gsub("^%s+", "")
          end
        else
          -- Для однострочного промпта: убираем весь промпт
          local prompt_text = state.current_prompt
          local prompt_end = line:find(vim.pesc(prompt_text), 1, true)
          if prompt_end then
            line = line:sub(prompt_end + #prompt_text)
            line = line:gsub("^%s+", "")
          end
        end
      end

      table.insert(command_lines, line)
    end

    -- Сохраняем информацию о команде
    state.current_command = {
      text = table.concat(command_lines, "\n"),
      lines = command_lines,
      prompt_line = state.current_prompt_info.start_line,
      prompt_end_line = state.current_prompt_info.end_line,
      enter_line = cursor_line,
      output_start_line = cursor_line + 1,
      timestamp = os.time(),
      prompt_is_multiline = state.current_prompt_info.is_multiline,
    }

  end

  state.state = STATES.WAITING_FOR_PROMPT
end

-- Monitor buffer changes
function M.on_lines_changed(bufnr)
  local state = M.terminals[bufnr]
  if not state then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new_line_count = #lines

  -- Check if new lines were added
  if new_line_count > state.last_line_count then
    local new_lines = {}
    for i = state.last_line_count + 1, new_line_count do
      if lines[i] then
        table.insert(new_lines, lines[i])
      end
    end
  end

  state.last_line_count = new_line_count
end

return M
