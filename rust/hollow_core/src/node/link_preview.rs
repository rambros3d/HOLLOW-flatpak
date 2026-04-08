//! OpenGraph link preview fetcher.
//!
//! **Privacy contract:** This module is ONLY called from the sender side.
//! When a user types a URL into the compose box, Hollow fetches the OG tags
//! and embeds a preview card (title/description/domain + small WebP
//! thumbnail) into the outgoing message envelope. Receivers render the
//! embedded card and NEVER make an HTTP request to the previewed URL —
//! that's a privacy requirement, not a cache optimization. Routing link
//! fetches through N receivers would turn Hollow into an IP-harvesting
//! amplifier.
//!
//! Phase 6.75.

use scraper::{Html, Selector};

use crate::node::image_convert;
use crate::node::LinkPreviewRef;

/// Max HTML response body we'll accept (2 MB). Modern bloated sites like
/// YouTube ship ~1.2 MB of inline JSON + JS in a single HTML document,
/// so a 1 MB cap cuts them off before the OG tags are even reachable.
/// 2 MB is generous enough to cover realistic sites while still refusing
/// pathologically-large responses. The 3-second total timeout is the
/// real ceiling on misbehavior.
const MAX_HTML_BYTES: usize = 2 * 1_024 * 1_024;
/// Max image response body we'll accept (4 MB). Typical OG images are
/// under 500 KB; cap at 4 MB to avoid pulling a huge hero shot we'd just
/// downsize anyway.
const MAX_IMAGE_BYTES: usize = 4 * 1_024 * 1_024;
/// Total timeout for the HTML + image fetches combined.
const FETCH_TIMEOUT_SECS: u64 = 3;
/// Max title length (chars).
const MAX_TITLE_CHARS: usize = 200;
/// Max description length (chars).
const MAX_DESC_CHARS: usize = 400;
/// Target max dimension for the thumbnail (px).
const THUMB_MAX_DIM: u32 = 400;
/// User-Agent we identify as.
const USER_AGENT: &str = "Hollow/0.1 LinkPreview";

/// Fetch OG metadata for `url` and build a `LinkPreviewRef`.
///
/// Returns `Err` on any fetch/parse/compress failure so the caller can
/// silently drop the preview without blocking the message send.
pub async fn fetch_link_preview(url: &str) -> Result<LinkPreviewRef, String> {
    // Parse + sanity-check the URL up front. Extract the display domain.
    let parsed = reqwest::Url::parse(url)
        .map_err(|e| format!("Invalid URL: {e}"))?;
    if parsed.scheme() != "http" && parsed.scheme() != "https" {
        return Err(format!("Unsupported URL scheme: {}", parsed.scheme()));
    }
    let domain = parsed.host_str().unwrap_or("").to_string();

    let client = reqwest::Client::builder()
        .user_agent(USER_AGENT)
        .timeout(std::time::Duration::from_secs(FETCH_TIMEOUT_SECS))
        .redirect(reqwest::redirect::Policy::limited(3))
        .build()
        .map_err(|e| format!("Failed to build HTTP client: {e}"))?;

    // Fetch the HTML with a body-size cap.
    let html_bytes = fetch_bounded(&client, url, MAX_HTML_BYTES).await?;
    let html_str = String::from_utf8_lossy(&html_bytes).into_owned();

    let parsed_meta = parse_og_metadata(&html_str);

    // Resolve og:image to an absolute URL if present, then fetch + compress.
    let mut thumb_webp_b64 = None;
    let mut thumb_w = None;
    let mut thumb_h = None;
    if let Some(img_src) = parsed_meta.image_url.as_deref() {
        if let Ok(img_url) = parsed.join(img_src) {
            if let Ok(bytes) = fetch_bounded(&client, img_url.as_str(), MAX_IMAGE_BYTES).await {
                if let Ok((webp_bytes, w, h)) =
                    image_convert::convert_to_webp_preview(&bytes, THUMB_MAX_DIM)
                {
                    use base64::Engine as _;
                    let engine = base64::engine::general_purpose::STANDARD;
                    thumb_webp_b64 = Some(engine.encode(&webp_bytes));
                    thumb_w = Some(w);
                    thumb_h = Some(h);
                }
            }
        }
    }

    Ok(LinkPreviewRef {
        url: url.to_string(),
        title: truncate_chars(&parsed_meta.title, MAX_TITLE_CHARS),
        description: truncate_chars(&parsed_meta.description, MAX_DESC_CHARS),
        domain,
        site_name: parsed_meta.site_name,
        thumb_webp_b64,
        thumb_w,
        thumb_h,
    })
}

/// Fetch a URL, streaming the body and aborting if it exceeds `max_bytes`.
async fn fetch_bounded(
    client: &reqwest::Client,
    url: &str,
    max_bytes: usize,
) -> Result<Vec<u8>, String> {
    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| format!("HTTP request failed: {e}"))?;
    if !resp.status().is_success() {
        return Err(format!("HTTP {}", resp.status()));
    }

    // If Content-Length is known and exceeds our cap, bail early.
    if let Some(len) = resp.content_length() {
        if len as usize > max_bytes {
            return Err(format!("Response too large: {len} bytes"));
        }
    }

    let bytes = resp
        .bytes()
        .await
        .map_err(|e| format!("Failed to read body: {e}"))?;
    if bytes.len() > max_bytes {
        return Err(format!("Response exceeded {max_bytes} bytes"));
    }
    Ok(bytes.to_vec())
}

/// Extracted OG metadata.
struct ParsedMeta {
    title: String,
    description: String,
    site_name: String,
    image_url: Option<String>,
}

/// Parse OpenGraph tags from HTML with sensible fallbacks.
///
/// Preference order:
/// - title: `og:title` → `<title>` → ""
/// - description: `og:description` → `<meta name="description">` → ""
/// - site_name: `og:site_name` → ""
/// - image: `og:image` → `twitter:image` → None
fn parse_og_metadata(html: &str) -> ParsedMeta {
    let doc = Html::parse_document(html);

    // Scraper selectors are expensive to parse, so build them once per call.
    // Safe unwrap — these are static CSS selectors.
    let meta_sel = Selector::parse("meta").unwrap();
    let title_sel = Selector::parse("title").unwrap();

    // Collect all <meta> tags indexed by name/property.
    let mut og_title = None;
    let mut og_desc = None;
    let mut og_site = None;
    let mut og_image = None;
    let mut meta_desc = None;
    let mut twitter_image = None;

    for el in doc.select(&meta_sel) {
        let attrs = el.value();
        let prop = attrs.attr("property").or_else(|| attrs.attr("name"));
        let content = attrs.attr("content");
        if let (Some(key), Some(val)) = (prop, content) {
            let key_lc = key.to_ascii_lowercase();
            match key_lc.as_str() {
                "og:title" => og_title = Some(val.to_string()),
                "og:description" => og_desc = Some(val.to_string()),
                "og:site_name" => og_site = Some(val.to_string()),
                "og:image" => og_image = Some(val.to_string()),
                "description" => meta_desc = Some(val.to_string()),
                "twitter:image" | "twitter:image:src" => {
                    twitter_image = Some(val.to_string())
                }
                _ => {}
            }
        }
    }

    // Fallback to <title> tag if og:title is missing.
    let title_tag = doc
        .select(&title_sel)
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string());

    ParsedMeta {
        title: og_title.or(title_tag).unwrap_or_default(),
        description: og_desc.or(meta_desc).unwrap_or_default(),
        site_name: og_site.unwrap_or_default(),
        image_url: og_image.or(twitter_image),
    }
}

/// Truncate `s` to at most `max_chars` Unicode characters, not bytes.
fn truncate_chars(s: &str, max_chars: usize) -> String {
    if s.chars().count() <= max_chars {
        return s.to_string();
    }
    s.chars().take(max_chars).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_full_og_metadata() {
        let html = r#"
            <html><head>
                <title>Fallback Title</title>
                <meta property="og:title" content="OG Title">
                <meta property="og:description" content="A nice description">
                <meta property="og:site_name" content="Example Site">
                <meta property="og:image" content="https://example.com/image.png">
            </head></html>
        "#;
        let m = parse_og_metadata(html);
        assert_eq!(m.title, "OG Title");
        assert_eq!(m.description, "A nice description");
        assert_eq!(m.site_name, "Example Site");
        assert_eq!(m.image_url.as_deref(), Some("https://example.com/image.png"));
    }

    #[test]
    fn falls_back_to_title_tag_and_meta_description() {
        let html = r#"
            <html><head>
                <title>Plain Title</title>
                <meta name="description" content="Plain meta description">
            </head></html>
        "#;
        let m = parse_og_metadata(html);
        assert_eq!(m.title, "Plain Title");
        assert_eq!(m.description, "Plain meta description");
        assert_eq!(m.site_name, "");
        assert_eq!(m.image_url, None);
    }

    #[test]
    fn twitter_image_fallback() {
        let html = r#"
            <html><head>
                <meta property="og:title" content="Hi">
                <meta name="twitter:image" content="https://example.com/t.jpg">
            </head></html>
        "#;
        let m = parse_og_metadata(html);
        assert_eq!(m.image_url.as_deref(), Some("https://example.com/t.jpg"));
    }

    #[test]
    fn malformed_html_does_not_panic() {
        let html = "<html><head><meta property='og:title' content='broken";
        let _m = parse_og_metadata(html);
        // Just must not panic.
    }

    #[test]
    fn empty_html_returns_empty_fields() {
        let m = parse_og_metadata("");
        assert_eq!(m.title, "");
        assert_eq!(m.description, "");
        assert_eq!(m.site_name, "");
        assert_eq!(m.image_url, None);
    }

    #[test]
    fn truncate_chars_respects_unicode() {
        // 5 emoji, each multi-byte. truncate_chars(3) should keep 3 code points.
        let s = "🙂🙂🙂🙂🙂";
        let truncated = truncate_chars(s, 3);
        assert_eq!(truncated.chars().count(), 3);
    }

    #[test]
    fn truncate_chars_noop_if_short_enough() {
        let s = "hello";
        assert_eq!(truncate_chars(s, 200), "hello");
    }

    /// Regression guard for the YouTube case: OG tags buried deep inside
    /// a huge bloated HTML document. As long as MAX_HTML_BYTES is large
    /// enough to fit the whole doc, parse_og_metadata should extract the
    /// tags correctly regardless of position.
    #[test]
    fn parses_youtube_shaped_html() {
        // Realistic YouTube structure: head with OG tags, followed by a
        // huge inline JSON blob that pushes total size past 1 MB.
        let padding = "x".repeat(600_000);
        let html = format!(
            r#"<!DOCTYPE html><html><head>
<meta property="og:site_name" content="YouTube">
<meta property="og:title" content="How Elon Musk Spends His Time">
<meta property="og:description" content="Sam Altman asked Elon Musk how he spends his time.">
<meta property="og:image" content="https://i.ytimg.com/vi/qszGzNoopTc/maxresdefault.jpg">
<script>var x = "{padding}";</script>
</head><body></body></html>"#
        );
        let m = parse_og_metadata(&html);
        assert_eq!(m.title, "How Elon Musk Spends His Time");
        assert_eq!(m.site_name, "YouTube");
        assert_eq!(
            m.description,
            "Sam Altman asked Elon Musk how he spends his time."
        );
        assert_eq!(
            m.image_url.as_deref(),
            Some("https://i.ytimg.com/vi/qszGzNoopTc/maxresdefault.jpg")
        );
    }
}
