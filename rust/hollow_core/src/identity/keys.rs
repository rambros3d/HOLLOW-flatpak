use std::fs;
use std::path::PathBuf;
use std::sync::OnceLock;

use bip39::Mnemonic;
use super::native_identity::NativeKeypair;

/// The result of identity generation/loading.
pub(crate) struct IdentityData {
    pub keypair: NativeKeypair,
    pub peer_id: String,
    pub mnemonic: Option<String>,
}

static DATA_DIR_OVERRIDE: OnceLock<String> = OnceLock::new();

/// Set the data directory path from Dart (Android/iOS pass their app data dir).
/// Must be called before any identity or storage operations.
pub fn set_data_dir(path: String) -> Result<(), String> {
    let _ = DATA_DIR_OVERRIDE.set(path);
    Ok(())
}

/// Get the Hollow data directory.
/// Priority: set_data_dir() override → HOLLOW_DATA_DIR env var → dirs::data_dir().
pub fn data_dir() -> Result<PathBuf, String> {
    let dir = if let Some(override_path) = DATA_DIR_OVERRIDE.get() {
        PathBuf::from(override_path)
    } else if let Ok(custom) = std::env::var("HOLLOW_DATA_DIR") {
        PathBuf::from(custom)
    } else {
        let base = dirs::data_dir().ok_or("Could not find app data directory")?;
        base.join("hollow")
    };
    fs::create_dir_all(&dir).map_err(|e| format!("Failed to create data dir: {e}"))?;
    Ok(dir)
}

/// Path to the stored identity keypair file.
fn keypair_path() -> Result<PathBuf, String> {
    Ok(data_dir()?.join("identity.key"))
}

/// Generate a brand new identity from a fresh BIP-39 mnemonic.
pub(crate) fn generate_new_identity() -> Result<IdentityData, String> {
    // Generate 24-word mnemonic (256 bits of entropy).
    let mut entropy = [0u8; 32];
    getrandom::fill(&mut entropy).map_err(|e| format!("RNG failed: {e}"))?;
    let mnemonic = Mnemonic::from_entropy(&entropy)
        .map_err(|e| format!("Mnemonic generation failed: {e}"))?;
    let mnemonic_phrase = mnemonic.to_string();

    let keypair = NativeKeypair::from_mnemonic(&mnemonic)?;
    let peer_id = keypair.peer_id();

    // Save the keypair to disk.
    save_keypair(&keypair)?;

    Ok(IdentityData {
        keypair,
        peer_id,
        mnemonic: Some(mnemonic_phrase),
    })
}

/// Restore an identity from an existing mnemonic phrase.
pub(crate) fn restore_identity_from_mnemonic(phrase: &str) -> Result<IdentityData, String> {
    let mnemonic: Mnemonic = phrase
        .parse()
        .map_err(|e| format!("Invalid mnemonic: {e}"))?;

    let keypair = NativeKeypair::from_mnemonic(&mnemonic)?;
    let peer_id = keypair.peer_id();

    // Save the restored keypair to disk.
    save_keypair(&keypair)?;

    Ok(IdentityData {
        keypair,
        peer_id,
        mnemonic: Some(mnemonic.to_string()),
    })
}

/// Load existing identity from disk, or create a new one if none exists.
/// If the identity file is encrypted, requires a session wrapping key
/// (set via `unlock_identity()` FFI call) to decrypt.
pub(crate) fn load_or_create_identity() -> Result<IdentityData, String> {
    let path = keypair_path()?;

    if path.exists() {
        let bytes = fs::read(&path).map_err(|e| format!("Failed to read identity file: {e}"))?;

        let plaintext = match super::encryption::detect_format(&bytes)? {
            super::encryption::IdentityFormat::Plaintext => bytes,
            super::encryption::IdentityFormat::Encrypted { .. } => {
                let key = super::encryption::get_session_key()
                    .ok_or("Identity is encrypted. Call unlock_identity() first.")?;
                super::encryption::decrypt_identity(&bytes, &key)?
            }
        };

        let keypair = NativeKeypair::from_protobuf_encoding(&plaintext)
            .map_err(|e| format!("Failed to decode identity: {e}"))?;
        let peer_id = keypair.peer_id();

        Ok(IdentityData {
            keypair,
            peer_id,
            mnemonic: None,
        })
    } else {
        generate_new_identity()
    }
}

/// Save a keypair to disk. If encryption is active (session key set),
/// the file is written as an encrypted HKEYV1 envelope. Otherwise plaintext protobuf.
fn save_keypair(keypair: &NativeKeypair) -> Result<(), String> {
    let path = keypair_path()?;
    let plaintext = keypair.to_protobuf_encoding()
        .map_err(|e| format!("Failed to encode keypair: {e}"))?;

    let bytes_to_write = if let Some(key) = super::encryption::get_session_key() {
        // Determine current protection flags by reading existing file (if any).
        let (password_used, os_keychain_used) = if path.exists() {
            let existing = fs::read(&path).unwrap_or_default();
            match super::encryption::detect_format(&existing) {
                Ok(super::encryption::IdentityFormat::Encrypted { flags, .. }) => {
                    (super::encryption::flags_has_password(flags),
                     super::encryption::flags_has_os_keychain(flags))
                }
                _ => (false, true), // Default: OS keychain only
            }
        } else {
            (false, true)
        };
        let mut salt = [0u8; 16];
        if password_used {
            getrandom::fill(&mut salt).map_err(|e| format!("RNG error: {e}"))?;
        }
        super::encryption::encrypt_identity(&plaintext, &key, &salt, password_used, os_keychain_used)?
    } else {
        plaintext
    };

    fs::write(&path, bytes_to_write).map_err(|e| format!("Failed to write identity file: {e}"))?;
    Ok(())
}
