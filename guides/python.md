# Python Code Style Guide

Modern Python 3.10+ patterns and best practices. Reference this on demand from your project's `CLAUDE.md` (e.g. "Before writing or reviewing code in this stack, read `~/.claude/guides/python.md`"). Do not `@import` it — that loads the full guide into every session.

## Type Hints — Modern Python 3.10+ Style

- **100% coverage** on all function signatures, return types, and instance variables
- `X | None` not `Optional[X]`; `list[X]` not `List[X]`; `dict[K, V]` not `Dict[K, V]`
- No `from typing import Optional, List, Dict, Tuple, Set` — use builtins
- Only import from `typing` for: `Callable`, `TypeVar`, `Protocol`, `TypeAlias`, `Any` (last resort)
- Annotate `self._foo: type` in `__init__` for non-obvious instance variables
- Never use `Any` as a shortcut — find the real type or use a `Protocol`

## Imports

- `from __future__ import annotations` at the top of every file (PEP 563 — enables forward refs, faster startup)
- **Order**: stdlib → third-party → local, separated by blank lines
- **Absolute imports only**: `from myproject.models import Signal`, never `from .models import Signal`
- Import specific names, never `import myproject` or `from X import *`
- Group multiple names from one module with parenthesized trailing comma

```python
from myproject.models import (
    OrderStatus,
    Side,
    Signal,
)
```

## Exception Handling

- **Catch specific exceptions** — never bare `except:` or `except Exception:` unless re-raising or at an outermost boundary
- **Never** `except SomeError: pass` — at minimum log, ideally handle
- Use `logger.exception("msg")` in except blocks (auto-includes traceback)
- Prefer EAFP (try/except) over LBYL (if checks) for external resources, but LBYL for logic flow
- Custom exceptions for domain errors: `class InsufficientBalanceError(ValueError):` is better than bare `ValueError`
- **No** `(bool, str)` tuples for error signaling — raise exceptions or return typed result objects

```python
# BAD
def check_order(order) -> tuple[bool, str]:
    if invalid:
        return False, "reason"
    return True, ""

# GOOD
def check_order(order) -> None:
    """Raises OrderValidationError if invalid."""
    if invalid:
        raise OrderValidationError("reason")
```

## Dataclasses & Data Models

- Use `@dataclass` for internal data containers
- Use `@dataclass(frozen=True)` for immutable value objects
- **Never** bare mutable defaults: `field(default_factory=list)` not `items: list = []`
- Use `@dataclass(slots=True)` on hot-path classes for memory/speed (Python 3.10+)
- Enums: inherit `str, enum.Enum` for JSON serialization
- Use pydantic `BaseModel` only for API request/response schemas and config — not for internal logic

## Async / Concurrency

- **`asyncio.gather(*tasks, return_exceptions=True)`** when tasks are independent — one failure must not kill others
- **`async with lock:`** for ALL reads and writes to shared mutable state — not just writes
- **Never** blocking I/O in async functions: no `open()`, `time.sleep()`, `requests.get()`, heavy CPU work
  - Use `asyncio.to_thread()` for CPU-bound work
  - Use `aiofiles` or `asyncio.to_thread(open, ...)` for file I/O
  - Use `asyncio.sleep()` not `time.sleep()`
- Fire-and-forget: `asyncio.create_task()` — but store a reference to avoid GC, add error callback
- **Task lifecycle**: always handle `asyncio.CancelledError`, always clean up in `finally`
- **Never** swallow `CancelledError` — re-raise it after cleanup

```python
# BAD — task can be garbage collected, errors silently lost
asyncio.create_task(self._dispatch(event))

# GOOD
task = asyncio.create_task(self._dispatch(event))
task.add_done_callback(self._handle_task_exception)
self._background_tasks.add(task)
task.add_done_callback(self._background_tasks.discard)
```

## Encapsulation & Access Control

- **Never** access `_private` attributes from outside the class — add a public property or method
- **Never** mutate another object's state directly — call a method on the owning object
- Use `@property` for computed read-only access
- Use descriptive method names that express intent: `bot.pause()` not `bot.state.paused = True`

## Logging

- One logger per module: `logger = logging.getLogger(__name__)`
- **Lazy formatting**: `logger.info("price=%s", price)` not `logger.info(f"price={price}")`
- **Levels**: DEBUG for internal state, INFO for lifecycle events, WARNING for degraded states, ERROR for failures
- **Never** log secrets, API keys, full API responses, or user credentials
- **Structured context**: Include relevant identifiers in every log message

## Database

- **Always** parameterized queries: `cursor.execute("... WHERE id = ?", (id,))` — never f-strings or `.format()`
- **Always** commit after writes
- **Batch operations**: `executemany()` not loops of `execute()`
- **Context managers** for connections
- **Use proper types**: INTEGER for booleans, REAL for floats, TEXT for strings

## Testing (pytest)

- **Class-based organization**: `class TestMyService:` — groups related tests
- **Plain `assert`** — no unittest methods (`assertEqual`, `assertTrue`)
- **`pytest.raises(ExceptionType, match=r"pattern")`** for expected errors
- **Async tests**: `async def test_something(self, fixture) -> None:`
- **Fixtures over setup**: Use `@pytest.fixture` not `setUp`/`tearDown`
- **In-memory resources**: `:memory:` for DB, mocks for external APIs
- **Test the behavior, not the implementation**: Assert on observable state changes
- **Name tests descriptively**: `test_rejects_expired_token_with_error_message`
- **Edge cases matter**: Empty data, None values, zero values, concurrent access, error paths

## FastAPI Endpoints

- **Dependency injection**: `Depends()` — never global mutable state
- **Pydantic models** for request bodies with `field: type | None = None` for optional fields
- **Return typed dicts or Pydantic models** — never untyped `dict`
- **Validate inputs**: Check ranges, allowed values — don't trust the client
- **HTTPException** for all error responses with meaningful `detail` messages
- **Plural nouns** for resource collections: `/trades`, `/positions`, `/signals`
- **POST for actions**: `/pause`, `/resume`, `/reset`

## General Python

- **DRY but not premature**: Extract a helper after the third repetition, not the first
- **Constants at module level**: `MAX_RETRIES = 5`, not magic numbers inline
- **Guard clauses**: Early return for edge cases, then the happy path — avoid deep nesting
- **Context managers** (`with`/`async with`) for anything that needs cleanup
- **Comprehensions over loops** when building simple collections: `[x.id for x in items]`
- **`pathlib.Path`** over `os.path` for file operations
- **f-strings** for string building (not `.format()` or `%`), except in logging (see above)

## Anti-Patterns (flag these)

### Python Anti-Patterns

| # | Anti-Pattern | Fix |
|---|---|---|
| P1 | Bare `except:` or `except Exception: pass` | Catch specific exception, always log |
| P2 | Mutable default arguments: `def f(items=[])` | Use `None` sentinel: `items: list | None = None` |
| P3 | Using `type()` for type checking | Use `isinstance()` |
| P4 | String concatenation in loops | Use `"".join()` or list comprehension |
| P5 | `import *` or wildcard imports | Import specific names |
| P6 | Bare `assert` in production code (not tests) | Use `if/raise` — asserts are stripped with `-O` |
| P7 | Nested try/except/try/except | Extract inner block to a function |
| P8 | Boolean arguments that change behavior | Use two methods or an enum parameter |
| P9 | God class with 10+ responsibilities | Split into focused classes |

### Async Anti-Patterns

| # | Anti-Pattern | Fix |
|---|---|---|
| A1 | `asyncio.gather()` without `return_exceptions=True` | Add `return_exceptions=True` |
| A2 | `time.sleep()` in async code | `await asyncio.sleep()` |
| A3 | Blocking I/O in async function | `asyncio.to_thread()` or async alternative |
| A4 | Fire-and-forget task without reference | Store ref, add error callback |
| A5 | Shared mutable state without lock | Use `asyncio.Lock` |
| A6 | Swallowing `CancelledError` | Always re-raise after cleanup |
| A7 | Sequential awaits for independent operations | Use `asyncio.gather()` |
| A8 | Lock held during I/O (DB, network) | Minimize critical section, copy data out then release |
