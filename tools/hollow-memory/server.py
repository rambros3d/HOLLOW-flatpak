import sys
from pathlib import Path

# Ensure the tool directory is on the path
sys.path.insert(0, str(Path(__file__).parent))

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("hollow-memory")


@mcp.tool()
def memory_search(query: str, limit: int = 5) -> str:
    """Semantic search across project memory files, HOLLOW_PLAN.md, WHITEPAPER.md, and CLAUDE.md.

    Use this to find relevant memories, architectural decisions, coding conventions,
    or phase details by meaning — not just keywords.

    Args:
        query: Natural language search query (e.g. "WebRTC reconnection issues" or "relay scaling decisions")
        limit: Maximum number of results to return (default 5)
    """
    from store import search, get_stats
    from embedder import embed

    stats = get_stats()
    if stats["total_chunks"] == 0:
        return "Index is empty. Run memory_reindex() first to build the search index."

    query_vec = embed([query])[0]
    results = search(query_vec, limit=limit)

    if not results:
        return "No results found."

    lines = [f"**Found {len(results)} results for:** \"{query}\"\n"]
    for i, r in enumerate(results, 1):
        score = max(0.0, 1.0 - r["distance"])
        lines.append(f"### {i}. {r['name']} (relevance: {score:.2f})")
        lines.append(f"Source: `{r['source']}` | Type: {r['chunk_type']}")
        snippet = r["content"][:400].replace("\n", " ").strip()
        if len(r["content"]) > 400:
            snippet += "..."
        lines.append(f"> {snippet}")
        lines.append("")

    return "\n".join(lines)


@mcp.tool()
def memory_reindex(force: bool = False) -> str:
    """Rebuild the semantic search index from source files.

    Incrementally updates by default (only re-embeds changed files).
    Use force=True for a full rebuild.

    Args:
        force: If True, drop all data and rebuild from scratch
    """
    from chunker import get_all_chunks
    from embedder import embed
    from store import upsert_chunks, rebuild

    chunks = get_all_chunks()
    if not chunks:
        return "No chunks found. Check that source files exist."

    texts = [c["content"] for c in chunks]
    embeddings = embed(texts)

    if force:
        rebuild(chunks, embeddings)
        return f"Full rebuild complete. Indexed {len(chunks)} chunks."
    else:
        result = upsert_chunks(chunks, embeddings)
        return (
            f"Reindex complete. "
            f"Inserted: {result['inserted']}, "
            f"Removed: {result['removed']}, "
            f"Unchanged: {result['unchanged']}. "
            f"Total: {len(chunks)} chunks."
        )


@mcp.tool()
def memory_stats() -> str:
    """Show statistics about the current search index."""
    from store import get_stats

    stats = get_stats()

    lines = [
        f"**Hollow Memory Index**",
        f"Total chunks: {stats['total_chunks']}",
        f"Last indexed: {stats['last_indexed'] or 'never'}",
        f"Database: {stats['db_path']}",
        "",
        "**By type:**",
    ]
    for chunk_type, count in sorted(stats["by_type"].items()):
        lines.append(f"  - {chunk_type}: {count}")

    return "\n".join(lines)


if __name__ == "__main__":
    # Eager initialization — load DB and model before MCP handshake
    # so tool calls don't block the stdio event loop
    from store import init_db
    from embedder import ensure_model, _get_tokenizer, _get_session

    init_db()
    ensure_model()
    _get_tokenizer()
    _get_session()

    print("hollow-memory: ready (94 chunks indexed)", file=sys.stderr)
    mcp.run()
