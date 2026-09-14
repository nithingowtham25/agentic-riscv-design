import json
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path

# Allow the bundled tamu_ai_chat package to be imported when lab1.py is run
# directly from either the lab root or the student_code directory.
LAB_ROOT = Path(__file__).resolve().parents[1]
if str(LAB_ROOT) not in sys.path:
    sys.path.insert(0, str(LAB_ROOT))


def _load_dotenv():
    """Load KEY=VALUE lines from a .env file at the package root into os.environ.

    Stdlib-only (no python-dotenv needed). Existing environment variables are not
    overwritten, so an exported key still takes precedence. Put your API key in a
    file named .env at the top level of the student package, e.g.:
        TAMUS_AI_CHAT_API_KEY=your_key
        # or
        OPENAI_API_KEY=sk-...
    """
    env_path = LAB_ROOT / ".env"
    if not env_path.exists():
        return
    _placeholders = {"your_key", "your_tamu_key_here", "sk-...", "", "changeme"}
    for raw in env_path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        # Ignore an obviously-unfilled placeholder so it can't "win" provider selection.
        if val in _placeholders:
            continue
        if key and key not in os.environ:
            os.environ[key] = val


_load_dotenv()


# Shared generation settings. Keep these identical across all your runs so the
# only thing that changes between runs is your prompt. Record them with every run.
DEFAULT_MAX_OUTPUT_TOKENS = 4096


@dataclass
class GenerationResult:
    """Structured result of one LLM call, for logging what your experiment used.

    Fields: content (the text), model (id returned by the API), usage (token counts,
    if the API reports them), provider, settings (the generation settings used, e.g.
    max output tokens), and raw (the full parsed JSON response).
    """
    content: str
    model: str = ""
    usage: dict = field(default_factory=dict)
    provider: str = ""
    settings: dict = field(default_factory=dict)
    raw: dict = field(default_factory=dict)


class LLMClient:
    provider = ""

    def generate(self, prompt, system_prompt=None):
        """Return the generated text (a string). The structured result of the most recent
        call is also stored on self.last (a GenerationResult) for logging."""
        raise NotImplementedError

    def generate_full(self, prompt, system_prompt=None):
        """Like generate(), but return the full GenerationResult (content + model + usage + raw)."""
        self.generate(prompt, system_prompt=system_prompt)
        return self.last

    def _record(self, content, model="", usage=None, raw=None):
        self.last = GenerationResult(
            content=content, model=model or self.model, usage=usage or {},
            provider=self.provider,
            settings={"max_output_tokens": getattr(self, "max_output_tokens", None)},
            raw=raw or {},
        )
        return content


class TamuAIChatClient(LLMClient):
    """Adapter for the bundled TAMU AI Chat API client."""
    provider = "tamu"

    def __init__(self, model, max_output_tokens=DEFAULT_MAX_OUTPUT_TOKENS):
        if not os.getenv("TAMUS_AI_CHAT_API_KEY"):
            raise RuntimeError("TAMUS_AI_CHAT_API_KEY is not set.")
        self.model = model
        self.max_output_tokens = max_output_tokens
        self.last = None

    def generate(self, prompt, system_prompt=None):
        """Send a prompt, optionally with stable system-level instructions."""
        from tamu_ai_chat import chat  # lazy import: only needed for the TAMU provider
        raw_response = chat(
            self.model,
            prompt=prompt,
            system_prompt=system_prompt,
            max_tokens=self.max_output_tokens,
        )
        try:
            response = json.loads(raw_response)
            content = response["choices"][0]["message"]["content"]
        except (json.JSONDecodeError, KeyError, IndexError, TypeError) as error:
            raise RuntimeError("TAMU AI Chat API returned an unexpected response.") from error

        if not isinstance(content, str) or not content:
            raise RuntimeError("TAMU AI Chat API returned an empty response.")
        return self._record(content, model=response.get("model", self.model),
                            usage=response.get("usage", {}), raw=response)


class OpenAIClient(LLMClient):
    """Adapter for the OpenAI Chat Completions API (uses OPENAI_API_KEY). Stdlib-only."""
    provider = "openai"

    def __init__(self, model, max_output_tokens=DEFAULT_MAX_OUTPUT_TOKENS):
        self.key = os.getenv("OPENAI_API_KEY")
        if not self.key:
            raise RuntimeError("OPENAI_API_KEY is not set.")
        self.model = model
        self.max_output_tokens = max_output_tokens
        self.last = None

    def generate(self, prompt, system_prompt=None):
        import urllib.request
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})
        body = json.dumps({
            "model": self.model,
            "messages": messages,
            "max_completion_tokens": self.max_output_tokens,
        }).encode()
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=body,
            headers={"Authorization": f"Bearer {self.key}", "Content-Type": "application/json"},
        )
        try:
            resp = json.loads(urllib.request.urlopen(req, timeout=180).read())
            content = resp["choices"][0]["message"]["content"]
        except Exception as error:
            raise RuntimeError("OpenAI API returned an unexpected response.") from error
        if not isinstance(content, str) or not content:
            raise RuntimeError("OpenAI API returned an empty response.")
        return self._record(content, model=resp.get("model", self.model),
                            usage=resp.get("usage", {}), raw=resp)


def build_llm_client(model, provider=None, max_output_tokens=DEFAULT_MAX_OUTPUT_TOKENS):
    """Return an LLM client for the configured model.

    provider: "tamu" or "openai". If None, auto-select by which API key is set
    (TAMUS_AI_CHAT_API_KEY -> TAMU; else OPENAI_API_KEY -> OpenAI). The two
    supported access paths both serve the same model. max_output_tokens is the
    shared output-length limit; keep it the same across all runs.
    """
    provider = (provider or os.getenv("A1_PROVIDER", "")).lower()
    if provider == "tamu":
        return TamuAIChatClient(model, max_output_tokens=max_output_tokens)
    if provider == "openai":
        return OpenAIClient(model, max_output_tokens=max_output_tokens)
    # auto-detect
    have_tamu = bool(os.getenv("TAMUS_AI_CHAT_API_KEY"))
    have_openai = bool(os.getenv("OPENAI_API_KEY"))
    if have_tamu and have_openai:
        raise RuntimeError(
            "Both TAMUS_AI_CHAT_API_KEY and OPENAI_API_KEY are set - which provider do you mean? "
            "Set only one, or pass --provider tamu|openai."
        )
    if have_tamu:
        return TamuAIChatClient(model, max_output_tokens=max_output_tokens)
    if have_openai:
        return OpenAIClient(model, max_output_tokens=max_output_tokens)
    raise RuntimeError(
        "No LLM key found. Set TAMUS_AI_CHAT_API_KEY (TAMU AI Chat) or OPENAI_API_KEY (OpenAI) - "
        "in a .env file at the package root or via export - or pass --provider."
    )
