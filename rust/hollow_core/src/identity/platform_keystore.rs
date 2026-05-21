use std::path::PathBuf;

fn dpapi_blob_path() -> Result<PathBuf, String> {
    Ok(super::keys::data_dir()?.join("identity.dpapi"))
}

pub(crate) fn is_available() -> bool {
    cfg!(any(windows, target_os = "macos"))
}

#[cfg(windows)]
mod win {
    use std::ptr;

    use windows_sys::Win32::Foundation::LocalFree;
    use windows_sys::Win32::Security::Cryptography::{
        CryptProtectData, CryptUnprotectData, CRYPT_INTEGER_BLOB,
    };

    pub(crate) fn protect(data: &[u8]) -> Result<Vec<u8>, String> {
        let input = CRYPT_INTEGER_BLOB {
            cbData: data.len() as u32,
            pbData: data.as_ptr() as *mut u8,
        };
        let mut output = CRYPT_INTEGER_BLOB {
            cbData: 0,
            pbData: ptr::null_mut(),
        };

        let ok = unsafe {
            CryptProtectData(
                &input,
                ptr::null(),     // description
                ptr::null_mut(), // optional entropy
                ptr::null_mut(), // reserved
                ptr::null_mut(), // prompt struct
                0,               // flags
                &mut output,
            )
        };

        if ok == 0 {
            return Err("DPAPI CryptProtectData failed".into());
        }

        let result =
            unsafe { std::slice::from_raw_parts(output.pbData, output.cbData as usize) }.to_vec();
        unsafe {
            LocalFree(output.pbData as *mut _);
        }
        Ok(result)
    }

    pub(crate) fn unprotect(data: &[u8]) -> Result<Vec<u8>, String> {
        let input = CRYPT_INTEGER_BLOB {
            cbData: data.len() as u32,
            pbData: data.as_ptr() as *mut u8,
        };
        let mut output = CRYPT_INTEGER_BLOB {
            cbData: 0,
            pbData: ptr::null_mut(),
        };

        let ok = unsafe {
            CryptUnprotectData(
                &input,
                ptr::null_mut(), // description out
                ptr::null_mut(), // optional entropy
                ptr::null_mut(), // reserved
                ptr::null_mut(), // prompt struct
                0,               // flags
                &mut output,
            )
        };

        if ok == 0 {
            return Err(
                "DPAPI CryptUnprotectData failed (identity was protected on a different account)"
                    .into(),
            );
        }

        let result =
            unsafe { std::slice::from_raw_parts(output.pbData, output.cbData as usize) }.to_vec();
        unsafe {
            LocalFree(output.pbData as *mut _);
        }
        Ok(result)
    }
}

#[cfg(target_os = "macos")]
mod mac {
    use security_framework::item::{ItemClass, ItemSearchOptions, Limit};
    use security_framework::passwords::{delete_generic_password, set_generic_password};

    const SERVICE: &str = "com.hollow.identity";
    const ACCOUNT: &str = "wrapping_key";

    pub(crate) fn store(key: &[u8]) -> Result<(), String> {
        let _ = delete_generic_password(SERVICE, ACCOUNT);
        set_generic_password(SERVICE, ACCOUNT, key)
            .map_err(|e| format!("macOS Keychain store failed: {e}"))
    }

    pub(crate) fn retrieve() -> Result<Option<Vec<u8>>, String> {
        let mut search = ItemSearchOptions::new();
        search
            .class(ItemClass::generic_password())
            .service(SERVICE)
            .account(ACCOUNT)
            .limit(Limit::Max(1))
            .load_data(true);

        match search.search() {
            Ok(results) => {
                if let Some(item) = results.first() {
                    if let Some(data) = item.data.as_ref() {
                        Ok(Some(data.to_vec()))
                    } else {
                        Ok(None)
                    }
                } else {
                    Ok(None)
                }
            }
            Err(e) if e.code() == -25300 => Ok(None), // errSecItemNotFound
            Err(e) => Err(format!("macOS Keychain retrieve failed: {e}")),
        }
    }

    pub(crate) fn delete() -> Result<(), String> {
        match delete_generic_password(SERVICE, ACCOUNT) {
            Ok(()) => Ok(()),
            Err(e) if e.code() == -25300 => Ok(()), // not found is fine
            Err(e) => Err(format!("macOS Keychain delete failed: {e}")),
        }
    }
}

pub(crate) fn store_key(key: &[u8]) -> Result<(), String> {
    #[cfg(windows)]
    {
        let blob = win::protect(key)?;
        let path = dpapi_blob_path()?;
        std::fs::write(&path, &blob).map_err(|e| format!("Failed to write DPAPI blob: {e}"))?;
        Ok(())
    }
    #[cfg(target_os = "macos")]
    {
        mac::store(key)
    }
    #[cfg(not(any(windows, target_os = "macos")))]
    {
        let _ = key;
        Err("OS keychain not available on this platform".into())
    }
}

pub(crate) fn retrieve_key() -> Result<Option<Vec<u8>>, String> {
    #[cfg(windows)]
    {
        let path = dpapi_blob_path()?;
        if !path.exists() {
            return Ok(None);
        }
        let blob =
            std::fs::read(&path).map_err(|e| format!("Failed to read DPAPI blob: {e}"))?;
        let plaintext = win::unprotect(&blob)?;
        Ok(Some(plaintext))
    }
    #[cfg(target_os = "macos")]
    {
        mac::retrieve()
    }
    #[cfg(not(any(windows, target_os = "macos")))]
    {
        Ok(None)
    }
}

#[allow(dead_code)]
pub(crate) fn delete_key() -> Result<(), String> {
    #[cfg(windows)]
    {
        let path = dpapi_blob_path()?;
        if path.exists() {
            std::fs::remove_file(&path)
                .map_err(|e| format!("Failed to delete DPAPI blob: {e}"))?;
        }
        Ok(())
    }
    #[cfg(target_os = "macos")]
    {
        mac::delete()
    }
    #[cfg(not(any(windows, target_os = "macos")))]
    {
        Ok(())
    }
}

/// Automatically protect a plaintext identity with the OS keychain if available.
/// Generates a random wrapping key, encrypts identity, stores key in OS credential store.
/// Returns Ok(true) if protection was applied, Ok(false) if not available.
pub(crate) fn auto_protect(
    identity_path: &std::path::Path,
    plaintext_bytes: &[u8],
) -> Result<bool, String> {
    if !is_available() {
        return Ok(false);
    }

    let mut wrapping_key = [0u8; 32];
    getrandom::fill(&mut wrapping_key).map_err(|e| format!("RNG error: {e}"))?;

    let salt = [0u8; 16]; // No password — salt is unused but kept for format consistency
    let encrypted = super::encryption::encrypt_identity(
        plaintext_bytes,
        &wrapping_key,
        &salt,
        false, // no password
        true,  // os keychain
    )?;

    store_key(&wrapping_key)?;
    wrapping_key.fill(0);

    std::fs::write(identity_path, &encrypted)
        .map_err(|e| format!("Failed to write encrypted identity: {e}"))?;

    Ok(true)
}
