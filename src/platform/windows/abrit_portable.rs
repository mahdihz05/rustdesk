use super::{abrit_identity, config, get_install_info, FLUTTER_RUNNER_WIN32_WINDOW_CLASS};
use hbb_common::{anyhow::anyhow, rand::Rng, sha2::{Digest, Sha256}, ResultType};
use std::sync::OnceLock;

static RUNTIME_NAME: OnceLock<String> = OnceLock::new();
static WINDOW_CLASS: OnceLock<String> = OnceLock::new();

pub(super) fn initialize() -> ResultType<()> {
    if RUNTIME_NAME.get().is_none() {
        let name = select_runtime_name()?;
        RUNTIME_NAME.set(name).map_err(|_| anyhow!("Runtime identity already initialized"))?;
    }
    *config::APP_NAME.write().unwrap() = runtime_name().to_owned();
    let command = std::env::args().nth(1).unwrap_or_default();
    if is_private() && !matches!(command.as_str(), "--identity-json" | "--connection-status-json" | "--version" | "--build-date") {
        prepare_private_profile()?;
    }
    Ok(())
}

// Do not inherit a namespace from the environment or command line: IPC authentication
// still requires the same executable. All run_me children derive it independently.
fn select_runtime_name() -> ResultType<String> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let command = args.iter().find(|arg| !matches!(arg.as_str(), "--elevate" | "--run-as-system" | "--quick_support" | "--no-server"));
    let explicit_installation = command.is_some_and(|arg| abrit_identity::installation_mode(arg))
        && !(command.is_some_and(|arg| arg == "--install") && config::is_disable_installation());
    let current = std::env::current_exe()?;
    let click_setup = args.is_empty() && crate::common::is_setup(&current.to_string_lossy());
    if explicit_installation || click_setup {
        return Ok(abrit_identity::APP_NAME.to_owned());
    }
    let (_, _, _, installed) = get_install_info();
    match std::fs::metadata(&installed) {
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(abrit_identity::APP_NAME.to_owned()),
        Err(err) => return Err(err.into()),
        Ok(_) => {}
    }
    let current = std::fs::canonicalize(current)?;
    let installed = std::fs::canonicalize(installed)?;
    let current = current.to_str().ok_or_else(|| anyhow!("Invalid executable path encoding"))?;
    let installed = installed.to_str().ok_or_else(|| anyhow!("Invalid installation path encoding"))?;
    if !abrit_identity::needs_private_runtime(current, Some(installed), false) {
        return Ok(abrit_identity::APP_NAME.to_owned());
    }
    Ok(portable_name(current))
}

fn portable_name(canonical_exe: &str) -> String {
    let hash = Sha256::digest(abrit_identity::runtime_path_key(canonical_exe).as_bytes());
    format!("{}-Portable-v2-{:x}", abrit_identity::APP_NAME, hash)
}

pub(super) fn is_private() -> bool {
    RUNTIME_NAME.get().is_some_and(|name| name != abrit_identity::APP_NAME)
}

pub(super) fn runtime_name() -> &'static str {
    RUNTIME_NAME.get().map(String::as_str).unwrap_or(abrit_identity::APP_NAME)
}

fn prepare_private_profile() -> ResultType<()> {
    use std::os::windows::fs::OpenOptionsExt;

    let config_file = config::Config::file();
    std::fs::create_dir_all(config_file.parent().ok_or_else(|| anyhow!("Missing portable configuration directory"))?)?;
    let _initialization = std::fs::OpenOptions::new().write(true).create(true)
        .truncate(false).share_mode(0).open(config_file.with_extension("portable-lock"))?;
    // Config's default ID comes from the MAC address, so separate files alone
    // would still register this host under the installed application's ID.
    // Seed and load it under the same lock in every process, before lazy Config
    // initialization. Config accepts a plain public ID and encrypts it on load.
    if !config_file.try_exists()? {
        let mut seed = config::Config::default();
        seed.id = hbb_common::rand::thread_rng().gen_range(1_000_000_000..2_000_000_000).to_string();
        config::store_path(config_file, seed)?;
    }
    if matches!(config::Config::get_id().parse::<u64>(), Ok(id) if id <= 0x1FFF_FFFF) {
        return Err(anyhow!("Invalid private portable identity; refusing a MAC-derived host ID"));
    }
    Ok(())
}

pub(super) fn window_class() -> &'static str {
    if !is_private() {
        return FLUTTER_RUNNER_WIN32_WINDOW_CLASS;
    }
    WINDOW_CLASS.get_or_init(|| format!("{}_{}", FLUTTER_RUNNER_WIN32_WINDOW_CLASS, runtime_name()))
}

#[no_mangle]
pub unsafe extern "C" fn get_abrit_runtime_window_class(buffer: *mut u16, capacity: i32) -> i32 {
    let value: Vec<_> = window_class().encode_utf16().chain(Some(0)).collect();
    if buffer.is_null() || capacity < 0 || (capacity as usize) < value.len() {
        return -1;
    }
    std::ptr::copy_nonoverlapping(value.as_ptr(), buffer, value.len());
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn portable_namespace_is_stable_and_separate_from_installed_and_stock() {
        let name = portable_name(r"C:\Portable\AbritDesk.exe");
        assert_eq!(name, portable_name(r"\\?\c:\portable\ABRITDESK.EXE"));
        assert_eq!(name, portable_name("c:/portable/abritdesk.exe"));
        assert_ne!(name, portable_name(r"C:\Other\AbritDesk.exe"));
        assert_ne!(name, abrit_identity::APP_NAME);
        assert_ne!(name, "RustDesk");
        assert_eq!(name.len(), "AbritDesk-Portable-v2-".len() + 64);
        assert!(name.strip_prefix("AbritDesk-Portable-v2-").unwrap().bytes().all(|byte| byte.is_ascii_hexdigit()));
    }
}
