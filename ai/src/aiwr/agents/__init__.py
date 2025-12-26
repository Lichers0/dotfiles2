"""Agent registry for AI coding assistants."""

from .base import BaseAgent
from .claude import ClaudeAgent
from .codex import CodexAgent
from .gemini import GeminiAgent
from .opencode import OpenCodeAgent

AGENTS: dict[str, BaseAgent] = {
    "claude": ClaudeAgent(),
    "gemini": GeminiAgent(),
    "codex": CodexAgent(),
    "opencode": OpenCodeAgent(),
}


def get_agent(name: str) -> BaseAgent:
    """Get agent by name."""
    if name not in AGENTS:
        available = ", ".join(AGENTS.keys())
        raise ValueError(f"Unknown agent: {name}. Available: {available}")
    return AGENTS[name]


def list_agents() -> list[str]:
    """Return list of available agent names."""
    return list(AGENTS.keys())


__all__ = [
    "BaseAgent",
    "ClaudeAgent",
    "GeminiAgent",
    "CodexAgent",
    "OpenCodeAgent",
    "get_agent",
    "list_agents",
]
