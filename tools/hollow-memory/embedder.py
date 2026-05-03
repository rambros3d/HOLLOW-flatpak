import sys
import numpy as np
from pathlib import Path

from config import ONNX_MODEL_PATH, TOKENIZER_PATH, MODELS_DIR, HF_MODEL_ID, EMBEDDING_DIM

_session = None
_tokenizer = None


def ensure_model():
    """Download model files if not present. Returns True if ready."""
    if ONNX_MODEL_PATH.exists() and TOKENIZER_PATH.exists():
        return True

    print("Downloading embedding model (first-time setup, ~45 MB)...", file=sys.stderr)
    from huggingface_hub import hf_hub_download

    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    if not ONNX_MODEL_PATH.exists():
        hf_hub_download(
            repo_id=HF_MODEL_ID,
            filename="onnx/model_O4.onnx",
            local_dir=str(MODELS_DIR),
            local_dir_use_symlinks=False,
        )

    if not TOKENIZER_PATH.exists():
        hf_hub_download(
            repo_id=HF_MODEL_ID,
            filename="tokenizer.json",
            local_dir=str(MODELS_DIR),
            local_dir_use_symlinks=False,
        )

    print("Model downloaded successfully.", file=sys.stderr)
    return True


def _get_tokenizer():
    global _tokenizer
    if _tokenizer is None:
        from tokenizers import Tokenizer
        _tokenizer = Tokenizer.from_file(str(TOKENIZER_PATH))
        _tokenizer.enable_truncation(max_length=128)
        _tokenizer.enable_padding(length=128)
    return _tokenizer


def _get_session():
    global _session
    if _session is None:
        import onnxruntime as ort
        _session = ort.InferenceSession(
            str(ONNX_MODEL_PATH),
            providers=["CPUExecutionProvider"],
        )
    return _session


def embed(texts: list[str]) -> np.ndarray:
    """Embed a list of texts into 384-dim normalized vectors."""
    ensure_model()
    tokenizer = _get_tokenizer()
    session = _get_session()

    encodings = tokenizer.encode_batch(texts)
    input_ids = np.array([e.ids for e in encodings], dtype=np.int64)
    attention_mask = np.array([e.attention_mask for e in encodings], dtype=np.int64)
    token_type_ids = np.array([e.type_ids for e in encodings], dtype=np.int64)

    outputs = session.run(None, {
        "input_ids": input_ids,
        "attention_mask": attention_mask,
        "token_type_ids": token_type_ids,
    })

    # Mean pooling with attention mask
    token_embeddings = outputs[0]  # [batch, seq_len, 384]
    mask_expanded = attention_mask[:, :, np.newaxis].astype(np.float32)
    sum_embeddings = np.sum(token_embeddings * mask_expanded, axis=1)
    sum_mask = np.sum(mask_expanded, axis=1).clip(min=1e-9)
    embeddings = sum_embeddings / sum_mask

    # L2 normalize
    norms = np.linalg.norm(embeddings, axis=1, keepdims=True).clip(min=1e-9)
    return (embeddings / norms).astype(np.float32)
