"""Runtime fixes for LiteLLM regressions used by this local proxy."""

from __future__ import annotations

from typing import Any


def _as_dict(event: Any) -> dict[str, Any]:
    if isinstance(event, dict):
        return event
    model_dump = getattr(event, "model_dump", None)
    if callable(model_dump):
        dumped = model_dump(mode="json", exclude_none=True)
        return dumped if isinstance(dumped, dict) else {}
    return {}


def _index(data: dict[str, Any], items: dict[int, dict[str, Any]]) -> int:
    try:
        return int(data.get("output_index"))
    except (TypeError, ValueError):
        return len(items)


def _capture_event(
    event: Any,
    items: dict[int, dict[str, Any]],
) -> None:
    data = _as_dict(event)
    event_type = data.get("type")
    output_index = _index(data, items)

    if event_type in ("response.output_item.added", "response.output_item.done"):
        item = data.get("item")
        if isinstance(item, dict):
            items[output_index] = item
        return

    if event_type in (
        "response.function_call_arguments.delta",
        "response.function_call_arguments.done",
    ):
        item = items.get(output_index)
        if not isinstance(item, dict) or item.get("type") != "function_call":
            return
        if event_type.endswith(".done"):
            item["arguments"] = data.get("arguments", item.get("arguments", ""))
        else:
            item["arguments"] = f"{item.get('arguments', '')}{data.get('delta', '')}"
        return

    if event_type not in ("response.output_text.delta", "response.output_text.done"):
        return

    item = items.setdefault(
        output_index,
        {
            "type": "message",
            "id": data.get("item_id") or f"msg_{output_index}",
            "role": "assistant",
            "status": "completed",
            "content": [],
        },
    )
    content = item.setdefault("content", [])
    if not isinstance(content, list):
        return
    try:
        content_index = int(data.get("content_index", 0))
    except (TypeError, ValueError):
        content_index = 0
    while len(content) <= content_index:
        content.append({"type": "output_text", "text": "", "annotations": []})
    block = content[content_index]
    if not isinstance(block, dict):
        block = {"type": "output_text", "text": "", "annotations": []}
        content[content_index] = block
    if event_type.endswith(".done"):
        block["text"] = data.get("text", block.get("text", ""))
    else:
        block["text"] = f"{block.get('text', '')}{data.get('delta', '')}"


def _install_chatgpt_stream_collector_fix() -> None:
    from litellm.completion_extras.litellm_responses_transformation.handler import (
        ResponsesToCompletionBridgeHandler,
    )
    from litellm.types.llms.openai import ResponsesAPIResponse

    def collect(self: Any, stream_iter: Any) -> ResponsesAPIResponse:
        items: dict[int, dict[str, Any]] = {}
        for event in stream_iter:
            _capture_event(event, items)
        return _finish(self, stream_iter, items)

    async def collect_async(self: Any, stream_iter: Any) -> ResponsesAPIResponse:
        items: dict[int, dict[str, Any]] = {}
        async for event in stream_iter:
            _capture_event(event, items)
        return _finish(self, stream_iter, items)

    def _finish(
        self: Any,
        stream_iter: Any,
        items: dict[int, dict[str, Any]],
    ) -> ResponsesAPIResponse:
        completed = getattr(stream_iter, "completed_response", None)
        response_obj = getattr(completed, "response", None) if completed else None
        if response_obj is None:
            raise ValueError("Stream ended without a completed response")
        response = self._coerce_response_object(
            response_obj,
            getattr(stream_iter, "_hidden_params", None),
        )
        if not response.output and items:
            response.output = list(dict(sorted(items.items())).values())
        return response

    ResponsesToCompletionBridgeHandler._collect_response_from_stream = collect
    ResponsesToCompletionBridgeHandler._collect_response_from_stream_async = collect_async


_install_chatgpt_stream_collector_fix()
