//! Image conversion utilities — WebP encoding for file sharing, avatars, and banners.

use image::imageops::FilterType;
use image::ImageFormat;

/// Extensions that should be converted to WebP on send.
/// GIFs are excluded to preserve animation frames.
pub fn should_convert_to_webp(ext: &str) -> bool {
    matches!(
        ext.to_lowercase().as_str(),
        "png" | "jpg" | "jpeg" | "bmp" | "tiff" | "tif"
    )
}

/// Convert image bytes to lossless WebP.
/// Returns (webp_bytes, width, height).
pub fn convert_to_webp_lossless(data: &[u8]) -> Result<(Vec<u8>, u32, u32), String> {
    let img = image::load_from_memory(data)
        .map_err(|e| format!("Failed to decode image: {e}"))?;

    let width = img.width();
    let height = img.height();

    let mut buf = Vec::new();
    let mut cursor = std::io::Cursor::new(&mut buf);

    img.write_to(&mut cursor, ImageFormat::WebP)
        .map_err(|e| format!("Failed to encode WebP: {e}"))?;

    Ok((buf, width, height))
}

/// Get image dimensions without converting.
pub fn get_image_dimensions(data: &[u8]) -> Result<(u32, u32), String> {
    let img = image::load_from_memory(data)
        .map_err(|e| format!("Failed to decode image: {e}"))?;
    Ok((img.width(), img.height()))
}

/// Convert image bytes to lossy WebP at quality 50, resized so the max
/// dimension is `max_dim_px`. Preserves aspect ratio. Used for link preview
/// thumbnails and any other "small preview image" use case where file size
/// matters more than pixel-perfect fidelity.
///
/// Returns `(webp_bytes, width, height)` where the dimensions are the
/// resized dimensions actually encoded. Phase 6.75.
pub fn convert_to_webp_preview(data: &[u8], max_dim_px: u32) -> Result<(Vec<u8>, u32, u32), String> {
    let img = image::load_from_memory(data)
        .map_err(|e| format!("Failed to decode image: {e}"))?;
    let (w, h) = (img.width(), img.height());
    if w == 0 || h == 0 {
        return Err("Image has zero dimensions".into());
    }

    // Resize so the larger dimension is at most max_dim_px. Preserve aspect.
    let resized = if w.max(h) > max_dim_px {
        let scale = max_dim_px as f32 / w.max(h) as f32;
        let nw = (w as f32 * scale).max(1.0) as u32;
        let nh = (h as f32 * scale).max(1.0) as u32;
        img.resize_exact(nw, nh, FilterType::Lanczos3)
    } else {
        img
    };

    let rgba = resized.to_rgba8();
    let (ew, eh) = (rgba.width(), rgba.height());
    let encoder = webp::Encoder::from_rgba(rgba.as_raw(), ew, eh);
    let webp_mem = encoder.encode(50.0); // Q=50 lossy
    Ok((webp_mem.to_vec(), ew, eh))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a tiny solid-color PNG in memory for test input.
    fn make_test_png(w: u32, h: u32) -> Vec<u8> {
        let img = image::RgbaImage::from_pixel(w, h, image::Rgba([128, 64, 200, 255]));
        let mut buf = Vec::new();
        let mut cursor = std::io::Cursor::new(&mut buf);
        img.write_to(&mut cursor, image::ImageFormat::Png)
            .expect("encode test png");
        buf
    }

    #[test]
    fn webp_preview_encodes_smaller_image() {
        let png = make_test_png(200, 100);
        let (webp_bytes, w, h) = convert_to_webp_preview(&png, 400).expect("encode");
        assert_eq!(w, 200);
        assert_eq!(h, 100);
        // Should decode cleanly via the image crate.
        let decoded = image::load_from_memory(&webp_bytes).expect("decode webp");
        assert_eq!(decoded.width(), 200);
        assert_eq!(decoded.height(), 100);
    }

    #[test]
    fn webp_preview_resizes_when_larger_than_max() {
        let png = make_test_png(1200, 600);
        let (webp_bytes, w, h) = convert_to_webp_preview(&png, 400).expect("encode");
        assert_eq!(w, 400);
        assert_eq!(h, 200); // preserved aspect ratio (1200:600 → 400:200)
        let decoded = image::load_from_memory(&webp_bytes).expect("decode webp");
        assert_eq!(decoded.width(), 400);
        assert_eq!(decoded.height(), 200);
    }

    #[test]
    fn webp_preview_rejects_invalid_bytes() {
        let result = convert_to_webp_preview(b"not an image", 400);
        assert!(result.is_err());
    }
}

/// Convert a WebP file to another format (for "Save As").
pub fn convert_from_webp(
    data: &[u8],
    target_format: &str,
) -> Result<Vec<u8>, String> {
    let img = image::load_from_memory(data)
        .map_err(|e| format!("Failed to decode image: {e}"))?;

    let format = match target_format.to_lowercase().as_str() {
        "png" => ImageFormat::Png,
        "jpg" | "jpeg" => ImageFormat::Jpeg,
        "bmp" => ImageFormat::Bmp,
        "gif" => ImageFormat::Gif,
        _ => return Err(format!("Unsupported target format: {target_format}")),
    };

    let mut buf = Vec::new();
    let mut cursor = std::io::Cursor::new(&mut buf);

    img.write_to(&mut cursor, format)
        .map_err(|e| format!("Failed to convert image: {e}"))?;

    Ok(buf)
}

/// Process a raw image into avatar format: center-crop to square, resize to 128x128, encode as WebP.
pub fn process_avatar_image(data: &[u8]) -> Result<Vec<u8>, String> {
    let img = image::load_from_memory(data)
        .map_err(|e| format!("Failed to decode image: {e}"))?;

    let (w, h) = (img.width(), img.height());
    let side = w.min(h);
    let x = (w - side) / 2;
    let y = (h - side) / 2;

    let cropped = img.crop_imm(x, y, side, side);
    let resized = cropped.resize_exact(128, 128, FilterType::Lanczos3);

    let mut buf = Vec::new();
    let mut cursor = std::io::Cursor::new(&mut buf);
    resized
        .write_to(&mut cursor, ImageFormat::WebP)
        .map_err(|e| format!("Failed to encode avatar WebP: {e}"))?;

    if buf.len() > 100_000 {
        return Err("Avatar image too large after processing (>100KB)".into());
    }

    Ok(buf)
}

/// Process a raw image into banner format: center-crop to 3:1 aspect, resize to 600x200, encode as WebP.
/// Accepts any image — crops the widest 3:1 region it can find, or stretches if very small.
pub fn process_banner_image(data: &[u8]) -> Result<Vec<u8>, String> {
    let img = image::load_from_memory(data)
        .map_err(|e| format!("Failed to decode image: {e}"))?;

    let (w, h) = (img.width(), img.height());
    if w == 0 || h == 0 {
        return Err("Image has zero dimensions".into());
    }

    // Target aspect 3:1 — crop the largest 3:1 region from center
    let (cw, ch) = if w * 1 >= h * 3 {
        // Image is wider than 3:1 — crop width
        (h * 3, h)
    } else {
        // Image is taller than 3:1 — crop height
        (w, (w / 3).max(1))
    };
    let x = (w - cw) / 2;
    let y = (h - ch) / 2;

    let cropped = img.crop_imm(x, y, cw, ch);
    let resized = cropped.resize_exact(600, 200, FilterType::Lanczos3);

    let mut buf = Vec::new();
    let mut cursor = std::io::Cursor::new(&mut buf);
    resized
        .write_to(&mut cursor, ImageFormat::WebP)
        .map_err(|e| format!("Failed to encode banner WebP: {e}"))?;

    if buf.len() > 200_000 {
        return Err("Banner image too large after processing (>200KB)".into());
    }

    Ok(buf)
}
