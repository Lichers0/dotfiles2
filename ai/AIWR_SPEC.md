# AIWR (AI Wrapper) — Спецификация

## Обзор

Универсальная CLI-обёртка над AI coding assistants (Claude Code, Gemini, Codex и др.) для логирования сессий с поддержкой вложенных вызовов и восстановления.

---

## 1. Расположение

### Код пакета (репозиторий)
```
~/dotfiles/ai/
├── pyproject.toml
├── README.md
├── AIWR_SPEC.md
└── src/
    └── aiwr/
        └── ...
```

### Логи (в каждом проекте)
```
{any_project}/
├── src/
├── .git/
└── .aiwr/
    └── logs/
        └── 2024-12-22/
            └── {session_id}.jsonl
```

---

## 2. Установка и запуск

### Установка
```bash
cd ~/dotfiles/ai
pip install -e .
```

### Команда (глобально доступна)
```bash
aiwr
```

---

## 3. CLI интерфейс

### Аргументы и флаги

| Аргумент/Флаг | Тип | Описание |
|---------------|-----|----------|
| `PROMPT` | positional | Промпт для AI assistant |
| `--agent` | string | Тип агента: `claude`, `gemini`, `codex`, `opencode` (по умолчанию: `claude`) |
| `--parent` | string | ID родительской сессии (для вложенных вызовов) |
| `--resume` | string | Восстановить одну сессию по ID |
| `--resume-tree` | string | Восстановить всё дерево сессий по ID |
| `--session` | string | Продолжить существующую сессию (дописать в лог) |
| `--list` | flag | Показать список всех сессий |
| `--` | separator | Разделитель для передачи аргументов агенту |

### Примеры использования

```bash
# Запуск с Claude Code (по умолчанию)
aiwr "fix the authentication bug"

# Запуск с Gemini
aiwr "fix the authentication bug" --agent gemini

# Запуск с OpenCode
aiwr "fix the authentication bug" --agent opencode

# Передача дополнительных аргументов агенту
aiwr "fix bug" --agent claude -- --model opus

# Вложенный вызов
aiwr "write unit tests" --parent a1b2c3d4

# Восстановление одной сессии
aiwr --resume a1b2c3d4

# Восстановление дерева
aiwr --resume-tree a1b2c3d4

# Продолжение существующей сессии
aiwr "continue work" --session a1b2c3d4

# Список сессий
aiwr --list
```

---

## 4. Конфигурация агентов

Конфигурация встроена в код (не внешний файл). Каждый агент отвечает за:
- Построение команды
- Фильтрацию вывода (только валидный JSON попадает в лог)
- Извлечение session_id, prompt, result, status

### Сводная таблица агентов

| Агент | Команда | Модель по умолчанию | Resume флаг |
|-------|---------|---------------------|-------------|
| Claude | `claude --verbose --output-format stream-json --model opus --print <prompt>` | `opus` | `--resume` |
| Gemini | `gemini --yolo --output-format stream-json --model gemini-3-pro-preview <prompt>` | `gemini-3-pro-preview` | `--resume` |
| Codex | `codex exec <prompt> --json --dangerously-bypass-approvals-and-sandbox --model gpt-5.2` | `gpt-5.2` | `resume` (позиц.) |
| OpenCode | `opencode run <prompt> --format json --model opencode/glm-4.7-free` | `opencode/glm-4.7-free` | `--session` |

### Базовый класс

```python
# src/aiwr/agents/base.py
from abc import ABC, abstractmethod

class BaseAgent(ABC):
    name: str                    # "claude", "gemini", "codex", "opencode"
    command: str                 # Команда CLI
    prompt_flag: str             # Флаг для промпта
    session_id_path: str         # JSONPath к session ID
    default_model: str | None    # Модель по умолчанию (опционально)
    resume_flag: str | None      # Флаг для продолжения сессии (опционально)

    def build_command(self, prompt: str, extra_args: list[str], session_id: str | None) -> list[str]:
        """Build full command with arguments."""
        ...

    def get_model(self, extra_args: list[str] | None) -> str | None:
        """Get model from extra_args or return default."""
        ...

    def parse_log_entry(self, line: str) -> dict | None:
        """Parse line and return JSON if valid log entry."""
        ...

    def extract_session_id(self, json_data: dict) -> str | None:
        """Extract session ID from JSON."""
        ...

    @abstractmethod
    def extract_result(self, json_data: dict) -> str | None:
        """Extract result text from JSON."""
        ...

    @abstractmethod
    def extract_prompt(self, json_data: dict) -> str | None:
        """Extract user prompt from JSON."""
        ...

    @abstractmethod
    def extract_status(self, json_data: dict) -> str | None:
        """Extract session status from JSON."""
        ...

    @abstractmethod
    def is_final(self, json_data: dict) -> bool:
        """Check if this JSON marks session end."""
        ...

    def should_reset_result(self, json_data: dict) -> bool:
        """Check if accumulated result should be reset.

        Override for agents that send multiple consecutive messages.
        Default: reset on any new result.
        """
        ...
```

### Реализация для Claude

```python
# src/aiwr/agents/claude.py
class ClaudeAgent(BaseAgent):
    name = "claude"
    command = "claude"
    prompt_flag = "--print"
    session_id_path = "$.session_id"
    default_model = "opus"
    resume_flag = "--resume"

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        cmd = [
            self.command,
            "--verbose",
            "--output-format", "stream-json",
        ]
        # Add resume flag if session_id provided (for --session)
        if session_id:
            cmd.extend([self.resume_flag, session_id])
        cmd.extend(["--print", prompt])
        # Add default model if not overridden
        if not (extra_args and "--model" in extra_args):
            cmd.extend(["--model", self.default_model])
        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def extract_result(self, json_data: dict) -> str | None:
        if json_data.get("type") == "result":
            return json_data.get("result")
        return None

    def extract_prompt(self, json_data: dict) -> str | None:
        if json_data.get("type") == "user":
            return json_data.get("content")
        return None

    def extract_status(self, json_data: dict) -> str | None:
        if json_data.get("type") == "result":
            return "completed"
        return None

    def is_final(self, json_data: dict) -> bool:
        return json_data.get("type") == "result"
```

### Реализация для Gemini

```python
# src/aiwr/agents/gemini.py
class GeminiAgent(BaseAgent):
    name = "gemini"
    command = "gemini"
    prompt_flag = ""  # positional argument
    session_id_path = "$.session_id"  # from type=init JSON
    default_model = "gemini-3-pro-preview"
    resume_flag = "--resume"

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        cmd = [
            self.command,
            "--yolo",
            "--output-format", "stream-json",
        ]
        # Add default model if not overridden
        if not (extra_args and "--model" in extra_args):
            cmd.extend(["--model", self.default_model])
        # Add resume flag if session_id provided
        if session_id:
            cmd.extend([self.resume_flag, session_id])
        cmd.append(prompt)
        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def extract_result(self, json_data: dict) -> str | None:
        # Result is in type=message with role=assistant
        if json_data.get("type") == "message" and json_data.get("role") == "assistant":
            return json_data.get("content")
        return None

    def extract_prompt(self, json_data: dict) -> str | None:
        if json_data.get("type") == "message" and json_data.get("role") == "user":
            return json_data.get("content")
        return None

    def extract_status(self, json_data: dict) -> str | None:
        if json_data.get("type") == "result":
            return json_data.get("status")  # "success" or "error"
        return None

    def is_final(self, json_data: dict) -> bool:
        return json_data.get("type") == "result"

    def should_reset_result(self, json_data: dict) -> bool:
        # Reset only on tool calls - they interrupt message flow
        if json_data.get("type") in ("tool_use", "tool_result"):
            return True
        return False
```

### Реализация для Codex

```python
# src/aiwr/agents/codex.py
class CodexAgent(BaseAgent):
    name = "codex"
    command = "codex"
    prompt_flag = ""  # positional argument
    session_id_path = "$.thread_id"  # from type=thread.started JSON
    default_model = "gpt-5.2"
    resume_flag = "resume"  # positional, not --resume

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        cmd = [
            self.command,
            "exec",
            prompt,
            "--json",
            "--dangerously-bypass-approvals-and-sandbox",
        ]
        # Add default model if not overridden
        if not (extra_args and "--model" in extra_args):
            cmd.extend(["--model", self.default_model])
        # Add resume if session_id provided
        if session_id:
            cmd.extend([self.resume_flag, session_id])
        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def extract_result(self, json_data: dict) -> str | None:
        if json_data.get("type") == "item.completed":
            item = json_data.get("item", {})
            return item.get("text")
        return None

    def extract_prompt(self, json_data: dict) -> str | None:
        if json_data.get("type") == "user.input":
            return json_data.get("text")
        return None

    def extract_status(self, json_data: dict) -> str | None:
        if json_data.get("type") == "turn.completed":
            return "completed"
        return None

    def is_final(self, json_data: dict) -> bool:
        return json_data.get("type") == "turn.completed"
```

### Реализация для OpenCode

```python
# src/aiwr/agents/opencode.py
class OpenCodeAgent(BaseAgent):
    name = "opencode"
    command = "opencode"
    prompt_flag = ""  # positional argument
    session_id_path = "$.sessionID"  # from any JSON event
    default_model = "opencode/glm-4.7-free"
    resume_flag = "--session"

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        cmd = [
            self.command,
            "run",
            prompt,
            "--format", "json",
        ]
        # Add default model if not overridden
        if not (extra_args and "--model" in extra_args):
            cmd.extend(["--model", self.default_model])
        # Add session flag if session_id provided
        if session_id:
            cmd.extend([self.resume_flag, session_id])
        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def extract_result(self, json_data: dict) -> str | None:
        # Result is in type=text with part.text
        if json_data.get("type") == "text":
            part = json_data.get("part", {})
            return part.get("text")
        return None

    def extract_prompt(self, json_data: dict) -> str | None:
        # OpenCode doesn't include user prompt in JSON output
        return None

    def extract_status(self, json_data: dict) -> str | None:
        if json_data.get("type") == "step_finish":
            part = json_data.get("part", {})
            reason = part.get("reason")
            if reason == "stop":
                return "completed"
            return reason
        return None

    def is_final(self, json_data: dict) -> bool:
        return json_data.get("type") == "step_finish"
```

---

## 5. Логирование

### Формат
- **Тип**: JSONL (JSON Lines)
- **Содержимое**: Только валидный JSON от агента, по одной записи на строку
- **Фильтрация**: Не-JSON вывод (мусор) игнорируется

### Расположение
```
{project}/.aiwr/logs/
```

### Ротация
- Без автоматической ротации
- Очистка вручную

---

## 6. Структура логов

### Правила именования

| Компонент | Формат |
|-----------|--------|
| ID сессии | Нативный из AI assistant |
| Корневой уровень | По дате: `{YYYY-MM-DD}/` |
| Имя файла | `{session_id}.jsonl` |
| Имя папки (если есть дети) | `{session_id}/` |

### Примеры структуры

#### Простая сессия (без вложенных)
```
.aiwr/
└── logs/
    └── 2024-12-22/
        └── a1b2c3d4.jsonl
```

#### Сессия с вложенными вызовами
```
.aiwr/
└── logs/
    └── 2024-12-22/
        └── a1b2c3d4/
            ├── a1b2c3d4.jsonl        # Родитель
            ├── e5f6g7h8.jsonl        # Дочерний
            └── i9j0k1l2/             # Дочерний с внуками
                ├── i9j0k1l2.jsonl
                └── m3n4o5p6.jsonl
```

### Правило конвертации файл → папка

Когда у сессии появляется первый дочерний вызов:
1. Файл `{id}.jsonl` перемещается в `{id}/{id}.jsonl`
2. Дочерний лог создаётся в `{id}/{child_id}.jsonl`

---

## 7. Формат JSONL лога

Лог содержит мета-информацию AIWR и чистый вывод агента — каждая строка это валидный JSON-объект:

```jsonl
{"type":"aiwr_start","prompt":"my name Denis","agent":"gemini","model":"gemini-3-pro-preview"}
{"type":"init","timestamp":"2025-12-22T16:53:54.835Z","session_id":"18ace3b2-4b0f-4c03-b5ff-e8d97db52582","model":"gemini-3-pro-preview"}
{"type":"message","timestamp":"2025-12-22T16:53:54.837Z","role":"user","content":"my name Denis"}
{"type":"message","timestamp":"2025-12-22T16:54:00.536Z","role":"assistant","content":"Hello Denis...","delta":true}
{"type":"result","timestamp":"2025-12-22T16:54:00.550Z","status":"success","stats":{"total_tokens":6688}}
```

### Мета-запись для вложенных сессий

Если сессия имеет родителя, первая строка содержит мета-информацию:

```jsonl
{"type":"aiwr_meta","parent_id":"a1b2c3d4"}
{"type":"init",...}
...
```

### Извлечение метаданных

Метаданные (agent, prompt, status, result) извлекаются из JSONL с помощью методов агента:

| Метаданные | Источник |
|------------|----------|
| `session_id` | Первый JSON с session_id/thread_id |
| `agent` | Определяется по формату JSON (type=init → gemini, thread_id → codex) |
| `prompt` | Из user message |
| `result` | Накопление последовательных assistant messages (Gemini) или из финального JSON |
| `status` | Из финального JSON (type=result) |
| `parent_id` | Из aiwr_meta записи |
| `children` | Сканирование JSONL файлов с aiwr_meta.parent_id |

### Накопление результата (Gemini)

Gemini отправляет несколько последовательных `message` с `role=assistant`. Они объединяются в один результат:

```
message assistant: "I have reviewed..."  ─┐
message assistant: " the workspace..."   ─┼─► "I have reviewed... the workspace..."
result                                    ─┘
```

Сброс происходит только при `tool_use` или `tool_result` (вызовы инструментов).

---

## 8. Формат вывода stdout

AIWR выводит в stdout **три JSON-объекта**:

### 1. Сразу при запуске (информация о запросе):
```json
{"type": "aiwr_start", "prompt": "my name Denis", "agent": "claude", "model": "opus"}
```
Эта запись также сохраняется первой строкой в JSONL лог-файл.

### 2. При получении первого JSON от агента (с session_id):
```json
{"session_id": "a1b2c3d4", "agent": "claude"}
```

### 3. При завершении (с результатом):
```json
{"result": "Hello Denis...", "agent": "gemini"}
```

### Полный пример вывода
```bash
$ aiwr "my name Denis" --agent claude
{"type": "aiwr_start", "prompt": "my name Denis", "agent": "claude", "model": "opus"}
{"session_id": "d798d333-caa0-4aab-8ae7-bcb459404165", "agent": "claude"}
{"result": "Привет, Денис! Чем могу помочь сегодня?", "agent": "claude"}
```

### Важно
- Промежуточный вывод агента **не транслируется** в stdout
- Только валидный JSON сохраняется в лог-файл

---

## 8.1. Продолжение сессии (--session)

При использовании `--session` данные дописываются в существующий лог-файл с разделителем:

```jsonl
{"type":"init",...}
{"type":"message",...}
----------
{"type":"init",...}
{"type":"message",...}
```

### Конвертация --session для агентов

| Агент | `--session uuid` конвертируется в |
|-------|-----------------------------------|
| Claude | `--resume uuid` |
| Gemini | `--resume uuid` |
| Codex | `resume uuid` (позиционный) |
| OpenCode | `--session uuid` |

### Важно (дополнительно)
- Мусор (не-JSON строки) игнорируется
- stderr агента **не транслируется** (подавляется)
- JSON выводится с `ensure_ascii=False` для корректного отображения Unicode

---

## 9. Вложенные вызовы

### Механизм
- Родитель указывается через `--parent <id>`
- В JSONL дочерней сессии добавляется `{"type": "aiwr_meta", "parent_id": "..."}`
- Дети находятся сканированием JSONL файлов
- Глубина вложенности: без ограничений

### Пример вызова из родительской сессии
```bash
# Родитель запускает
aiwr "implement feature"
# stdout: {"session_id": "a1b2c3d4"}

# Внутри AI assistant вызывается
aiwr "write tests for feature" --parent a1b2c3d4
# stdout: {"session_id": "e5f6g7h8"} ... {"result": "..."}
```

### Структура при вложенности
```
logs/2024-12-22/
└── a1b2c3d4/
    ├── a1b2c3d4.jsonl    # без aiwr_meta
    └── e5f6g7h8.jsonl    # {"type":"aiwr_meta","parent_id":"a1b2c3d4"}
```

---

## 10. Восстановление сессий

### Механизм
- Контекст передаётся через системный промпт
- JSONL-записи включаются в контекст
- Метаданные извлекаются из JSONL

### --resume <id>
Восстанавливает только указанную сессию.

### --resume-tree <id>
Восстанавливает всё дерево:
1. Загружает корневую сессию
2. Находит всех детей (сканирование aiwr_meta)
3. Рекурсивно загружает детей
4. Формирует полный контекст с иерархией

---

## 11. Обработка прерываний

### Ctrl+C
1. Перехватить SIGINT
2. Завершить процесс агента
3. Сохранить накопленный JSONL
4. Корректно завершить процесс (exit code 130)

---

## 12. Команда --list

### Вывод
```
Sessions (2024-12-22):
  a1b2c3d4  [claude]  [completed]  "fix the authentication bug"
  e5f6g7h8  [gemini]  [success]  "implement feature X"
    └─ i9j0k1l2  [claude]  [completed]  "write tests"

Sessions (2024-12-21):
  x1y2z3w4  [claude]  [completed]  "refactor utils"
```

### Алгоритм
1. Сканировать `logs/` по датам (новые первые)
2. Для каждого JSONL извлечь метаданные
3. Найти детей через aiwr_meta
4. Построить дерево и вывести с отступами

---

## 13. Структура проекта

### Репозиторий (~/dotfiles/ai/)

```
~/dotfiles/ai/
├── pyproject.toml
├── README.md
├── AIWR_SPEC.md
└── src/
    └── aiwr/
        ├── __init__.py         # Версия пакета
        ├── cli.py              # Entry point, argparse, main()
        ├── agents/
        │   ├── __init__.py     # Реестр агентов: get_agent()
        │   ├── base.py         # BaseAgent абстрактный класс
        │   ├── claude.py       # ClaudeAgent
        │   ├── gemini.py       # GeminiAgent
        │   ├── codex.py        # CodexAgent
        │   └── opencode.py     # OpenCodeAgent
        ├── runner.py           # Запуск subprocess, фильтрация, логирование
        ├── logger.py           # Запись JSONL логов
        ├── session.py          # Поиск сессий, file→dir конвертация
        ├── resume.py           # Извлечение метаданных, промпт для --resume
        └── tree.py             # Построение дерева для --list
```

### Логи в проекте (создаются автоматически)

```
{любой_проект}/
├── src/
├── .git/
└── .aiwr/
    └── logs/
        └── {YYYY-MM-DD}/
            └── {session_id}.jsonl
```

---

## 14. Зависимости

```toml
[project]
name = "aiwr"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = []

[project.scripts]
aiwr = "aiwr.cli:main"
```

Без внешних зависимостей — только стандартная библиотека Python.

---

## 15. Обработка ошибок

| Ситуация | Действие |
|----------|----------|
| Агент не найден | Ошибка: "{agent} not found in PATH" |
| Неизвестный агент | Ошибка: "Unknown agent: {agent}. Available: claude, gemini, codex, opencode" |
| Невалидный --parent ID | Ошибка: "Parent session not found: {id}" |
| Невалидный --resume ID | Ошибка: "Session not found: {id}" |
| Нет прав на запись логов | Ошибка: "Cannot write to .aiwr/logs/" |
| Агент вернул ошибку | Сохранить JSONL как есть |

---

## 16. Переменные окружения

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `AIWR_LOG_DIR` | Переопределить путь к логам | `.aiwr/logs/` |
| `AIWR_DEFAULT_AGENT` | Агент по умолчанию | `claude` |

---

## 17. Будущие расширения (не в MVP)

- `--verbose` — подробный вывод
- `--quiet` — минимальный вывод
- `--tag` — теги для сессий
- `--search` — поиск по сессиям
- `--export` — экспорт в другие форматы
- `--diff` — сравнение сессий
- Web UI для просмотра логов
- Поддержка дополнительных агентов
