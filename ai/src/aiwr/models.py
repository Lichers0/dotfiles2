# src/aiwr/models.py
"""Model definitions for AI agents."""

from typing import NamedTuple


class ModelInfo(NamedTuple):
    """Resolved model information."""

    model_id: str
    extra_args: list[str]


MODELS = {
    "claude": [
        {"alias": "opus", "default": True, "model_id": "opus", "extra_args": []},
        {"alias": "sonnet", "default": False, "model_id": "sonnet", "extra_args": []},
        {"alias": "haiku", "default": False, "model_id": "haiku", "extra_args": []},
    ],
    "codex": [
        {"alias": "gpt52codex", "default": True, "model_id": "gpt-5.2-codex", "extra_args": []},
        {"alias": "gpt52", "default": False, "model_id": "gpt-5.2", "extra_args": []},
    ],
    "gemini": [
        {"alias": "pro", "default": True, "model_id": "gemini-3-pro", "extra_args": []},
        {"alias": "flash", "default": False, "model_id": "gemini-3-flash", "extra_args": []},
    ],
    "opencode": [
        {"alias": "glm", "default": True, "model_id": "cerebras/zai-glm-4.6", "extra_args": []},
    ],
}


def resolve_model(agent_name: str, alias: str) -> ModelInfo:
    """Resolve model alias to model_id and extra_args.

    Args:
        agent_name: Agent name (claude, codex, gemini, opencode)
        alias: Model alias

    Returns:
        ModelInfo with model_id and extra_args

    Raises:
        ValueError: If agent or model not found
    """
    if agent_name not in MODELS:
        raise ValueError(f"Unknown agent: {agent_name}")

    for model in MODELS[agent_name]:
        if model["alias"] == alias:
            return ModelInfo(model["model_id"], list(model["extra_args"]))

    available = ", ".join(m["alias"] for m in MODELS[agent_name])
    raise ValueError(
        f"Model '{alias}' not found for agent '{agent_name}'. Available: {available}"
    )


def get_default_model(agent_name: str) -> ModelInfo:
    """Get default model for an agent.

    Args:
        agent_name: Agent name

    Returns:
        ModelInfo with model_id and extra_args

    Raises:
        ValueError: If agent not found or no default model
    """
    if agent_name not in MODELS:
        raise ValueError(f"Unknown agent: {agent_name}")

    for model in MODELS[agent_name]:
        if model["default"]:
            return ModelInfo(model["model_id"], list(model["extra_args"]))

    raise ValueError(f"No default model for agent '{agent_name}'")


def merge_extra_args(model_args: list[str], cli_args: list[str]) -> list[str]:
    """Merge model extra_args with CLI extra_args.

    CLI args override model args for the same flags.

    Args:
        model_args: Extra args from model config
        cli_args: Extra args from command line

    Returns:
        Merged list of args with CLI priority
    """
    if not model_args:
        return cli_args
    if not cli_args:
        return model_args

    # Parse CLI args to find which flags are overridden
    cli_flags = set()
    i = 0
    while i < len(cli_args):
        arg = cli_args[i]
        if arg.startswith("-"):
            cli_flags.add(arg)
        i += 1

    # Filter model args - skip flags that are in CLI
    result = []
    i = 0
    while i < len(model_args):
        arg = model_args[i]
        if arg.startswith("-"):
            if arg in cli_flags:
                # Skip this flag and its value
                i += 1
                if i < len(model_args) and not model_args[i].startswith("-"):
                    i += 1
                continue
        result.append(arg)
        i += 1

    # Append all CLI args
    result.extend(cli_args)
    return result
