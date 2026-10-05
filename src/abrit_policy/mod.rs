pub mod model;
#[cfg(all(target_os = "windows", feature = "flutter"))]
mod runtime;

pub fn enabled() -> bool {
    cfg!(all(target_os = "windows", feature = "flutter"))
        && option_env!("ABRIT_CLIENT_API").is_some_and(|url| !url.is_empty())
}
pub fn blocked() -> bool {
    #[cfg(all(target_os = "windows", feature = "flutter"))]
    if enabled() { runtime::start(); return runtime::blocked(); }
    false
}
pub fn start() {
    #[cfg(all(target_os = "windows", feature = "flutter"))]
    if enabled() { runtime::start(); }
}
pub fn get_option(key: &str) -> Option<String> {
    #[cfg(all(target_os = "windows", feature = "flutter"))]
    if key == "abrit-control-state" { return Some(runtime::snapshot()); }
    let _ = key;
    None
}
pub fn set_option(key: &str) -> bool {
    #[cfg(all(target_os = "windows", feature = "flutter"))]
    if key == "abrit-control-refresh" { runtime::refresh(); return true; }
    let _ = key;
    false
}
pub const BLOCK_REASON: &str = "abritdesk must be updated before it can be used.";
