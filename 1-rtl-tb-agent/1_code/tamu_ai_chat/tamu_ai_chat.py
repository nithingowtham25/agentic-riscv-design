#!/usr/bin/env python3
"""Minimal CLI wrapper for TAMU AI Chat API.

Usage examples:
  python tamu_ai_chat.py models
  python tamu_ai_chat.py chat --model protected.gemini-2.0-flash-lite --prompt "Why is the sky blue?"
  echo "Why is the sky blue?" | python tamu_ai_chat.py chat --model protected.gemini-2.0-flash-lite
  python tamu_ai_chat.py chat --model protected.gemini-2.0-flash-lite \
      --message user:"Why is the sky blue?" --message system:"Keep it brief."
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import List, Dict, Any, Sequence

DEFAULT_ENDPOINT = "https://chat-api.tamu.ai"
# Non-authoritative hint only. The live catalog can change during the semester; run the
# `models` subcommand for the current list. The API accepts any valid model name (e.g. gpt-5.4).
AVAILABLE_MODELS = [
    "o3",
    "Claude Opus 4.1",
    "Claude-Haiku-4.5",
    "Claude 3.5 Sonnet",
    "gemini-2.0-flash",
    "Claude Sonnet 4.5",
    "Claude 3.5 Haiku",
    "o4-mini",
    "gemini-2.5-flash-lite",
    "Claude Opus 4.5",
    "gemini-2.5-pro",
    "gemini-2.0-flash-lite",
    "Claude Sonnet 4",
    "gpt-4.1",
    "gpt-4o",
    "text-embedding-3-small",
    "o3-mini",
    "gpt-5.1",
    "gemini-2.5-flash",
    "gpt-5",
    "llama3.2",
    "Claude 3.7 Sonnet",
    "gpt-5.2",
    "gpt-5.4",
]

# Requests that exceed this many seconds are aborted rather than hanging.
DEFAULT_TIMEOUT_SECONDS = 180


def _env_or_default(name: str, default: str | None = None) -> str | None:
    val = os.environ.get(name)
    if val is not None and val.strip() == "":
        return default
    return val if val is not None else default


def _require_env(name: str) -> str:
    val = _env_or_default(name)
    if not val:
        raise SystemExit(f"Missing required env var: {name}")
    return val


def _build_url(endpoint: str, path: str) -> str:
    endpoint = endpoint.rstrip("/")
    if not path.startswith("/"):
        path = "/" + path
    return endpoint + path


def _redact_headers(headers: Dict[str, str]) -> Dict[str, str]:
    redacted: Dict[str, str] = {}
    for k, v in headers.items():
        if k.lower() == "authorization":
            redacted[k] = "Bearer ***"
        else:
            redacted[k] = v
    return redacted


def _debug_print(debug: bool, text: str) -> None:
    if debug:
        sys.stderr.write(text)
        if not text.endswith("\n"):
            sys.stderr.write("\n")


def _request(
    method: str,
    url: str,
    api_key: str,
    payload: Dict[str, Any] | None = None,
    debug: bool = False,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    data = None
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
        # Cloudflare may block requests without a User-Agent header.
        "User-Agent": "tamu-ai-chat/1.0",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    _debug_print(debug, f"> {method} {url}")
    if debug:
        for k, v in _redact_headers(headers).items():
            _debug_print(debug, f"> {k}: {v}")
        if payload is not None:
            _debug_print(debug, ">")
            _debug_print(debug, json.dumps(payload, ensure_ascii=True, indent=2))
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            _debug_print(debug, f"< HTTP {resp.status}")
            if debug:
                for k, v in resp.headers.items():
                    _debug_print(debug, f"< {k}: {v}")
                _debug_print(debug, "<")
            return resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        _debug_print(debug, f"< HTTP {e.code}")
        if debug:
            for k, v in e.headers.items():
                _debug_print(debug, f"< {k}: {v}")
            _debug_print(debug, "<")
            _debug_print(debug, body)
        raise SystemExit(f"HTTP {e.code} for {method} {url}: {body}")
    except urllib.error.URLError as e:
        raise SystemExit(f"Request failed: {e}")


def _parse_messages(message_args: List[str], prompt: str | None) -> List[Dict[str, str]]:
    messages: List[Dict[str, str]] = []

    for m in message_args:
        if ":" not in m:
            raise SystemExit("--message must be in the form role:content")
        role, content = m.split(":", 1)
        role = role.strip()
        content = content.strip()
        if not role or not content:
            raise SystemExit("--message must include a non-empty role and content")
        messages.append({"role": role, "content": content})

    if messages:
        return messages

    if prompt is None:
        # If stdin is piped, read it as the user prompt.
        if not sys.stdin.isatty():
            prompt = sys.stdin.read().strip()

    if not prompt:
        raise SystemExit("No prompt provided. Use --prompt, --message, or pipe stdin.")

    return [{"role": "user", "content": prompt}]


def _validate_messages(messages: Sequence[Dict[str, str]]) -> List[Dict[str, str]]:
    out: List[Dict[str, str]] = []
    for msg in messages:
        if not isinstance(msg, dict):
            raise SystemExit("Each message must be a dict with role and content.")
        role = str(msg.get("role", "")).strip()
        content = str(msg.get("content", "")).strip()
        if not role or not content:
            raise SystemExit("Each message dict must include non-empty role and content.")
        out.append({"role": role, "content": content})
    return out


def _build_messages(
    prompt: str | None,
    message_args: Sequence[str] | None,
    messages: Sequence[Dict[str, str]] | None,
    system_prompt: str | None,
) -> List[Dict[str, str]]:
    has_cli_messages = bool(message_args)
    has_structured_messages = bool(messages)
    has_system_prompt = bool(system_prompt and system_prompt.strip())

    if has_cli_messages and has_structured_messages:
        raise SystemExit("Use either message_args or messages, not both.")

    built: List[Dict[str, str]] = []
    if has_cli_messages:
        built = _parse_messages(list(message_args or []), prompt=None)
    elif has_structured_messages:
        built = _validate_messages(messages or [])
    elif prompt:
        built = [{"role": "user", "content": prompt}]
    elif not sys.stdin.isatty():
        stdin_prompt = sys.stdin.read().strip()
        if stdin_prompt:
            built = [{"role": "user", "content": stdin_prompt}]

    if has_system_prompt:
        built.insert(0, {"role": "system", "content": system_prompt.strip()})

    if not built:
        raise SystemExit(
            "No prompt/messages provided. Use prompt, message_args/messages, or pipe stdin."
        )
    return built


def _normalize_model(model: str) -> str:
    model = model.strip()
    if model.startswith("protected."):
        return model
    return f"protected.{model}"


def _pretty_print(text: str, raw: bool) -> None:
    if raw:
        sys.stdout.write(text)
        if not text.endswith("\n"):
            sys.stdout.write("\n")
        return

    try:
        obj = json.loads(text)
    except json.JSONDecodeError:
        sys.stdout.write(text)
        if not text.endswith("\n"):
            sys.stdout.write("\n")
        return

    sys.stdout.write(json.dumps(obj, ensure_ascii=True, indent=2))
    sys.stdout.write("\n")


def models(
    *,
    debug: bool = False,
    api_key: str | None = None,
    endpoint: str | None = None,
) -> Dict[str, Any] | List[Any] | str:
    """List available models from TAMU AI Chat API.

    Returns parsed JSON by default; pass raw=True for raw response text.
    """
    api_key = api_key or _require_env("TAMUS_AI_CHAT_API_KEY")
    endpoint = endpoint or _env_or_default("TAMUS_AI_CHAT_API_ENDPOINT", DEFAULT_ENDPOINT)
    url = _build_url(endpoint, "/openai/models")
    text = _request("GET", url, api_key, debug=debug)
    return text


def chat(
    model: str,
    *,
    prompt: str | None = None,
    message_args: Sequence[str] | None = None,
    messages: Sequence[Dict[str, str]] | None = None,
    system_prompt: str | None = None,
    stream: bool = False,
    max_tokens: int | None = None,
    debug: bool = False,
    api_key: str | None = None,
    endpoint: str | None = None,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> Dict[str, Any] | List[Any] | str:
    """Send chat completion request.

    Compatible with CLI semantics:
    - Provide `message_args=["role:content", ...]` to mirror repeated --message usage.
    - Provide `messages=[{"role":"...", "content":"..."}, ...]` for Python-native context.
    - Provide `system_prompt` to prepend a system message.
    - If messages are provided, prompt is ignored.
    """
    api_key = api_key or _require_env("TAMUS_AI_CHAT_API_KEY")
    endpoint = endpoint or _env_or_default("TAMUS_AI_CHAT_API_ENDPOINT", DEFAULT_ENDPOINT)
    url = _build_url(endpoint, "/openai/chat/completions")

    use_prompt = None if (message_args or messages) else prompt
    built_messages = _build_messages(use_prompt, message_args, messages, system_prompt)
    payload: Dict[str, Any] = {
        "model": _normalize_model(model),
        "stream": bool(stream),
        "messages": built_messages,
    }
    if max_tokens is not None:
        payload["max_tokens"] = int(max_tokens)

    text = _request("POST", url, api_key, payload=payload, debug=debug, timeout=timeout)
    return text


def cmd_models(args: argparse.Namespace) -> None:
    text = models(debug=args.debug)
    _pretty_print(text, args.raw)


def cmd_chat(args: argparse.Namespace) -> None:
    text = chat(
        args.model,
        prompt=args.prompt,
        message_args=args.message or [],
        stream=args.stream,
        debug=args.debug,
    )
    _pretty_print(text, args.raw)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="TAMU AI Chat CLI wrapper")
    parser.add_argument("--debug", action="store_true", help="Print request/response headers to stderr")
    sub = parser.add_subparsers(dest="command", required=True)

    p_models = sub.add_parser("models", help="List available models")
    p_models.add_argument("--raw", action="store_true", help="Print raw JSON without pretty formatting")
    p_models.set_defaults(func=cmd_models)

    p_chat = sub.add_parser("chat", help="Send a chat completion request")
    p_chat.add_argument(
        "--model",
        required=True,
        help=(
            "Model name, e.g. gpt-5.4 (the 'protected.' prefix is optional and added "
            "automatically). Run the 'models' subcommand for the current live list."
        ),
    )
    p_chat.add_argument("--prompt", help="User prompt (ignored if --message is provided)")
    p_chat.add_argument(
        "--message",
        action="append",
        help='Full message in role:content form; can be repeated, e.g. --message system:"You are helpful"',
    )
    p_chat.add_argument("--stream", action="store_true", help="Request streaming responses (if supported)")
    p_chat.add_argument("--raw", action="store_true", help="Print raw JSON without pretty formatting")
    p_chat.set_defaults(func=cmd_chat)

    return parser


def main(argv: List[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
