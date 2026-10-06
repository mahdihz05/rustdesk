pub const APP_NAME: &str = "AbritDesk";
pub const SERVICE_DISPLAY_NAME: &str = "AbritDesk Service";
pub const SERVER: &str = "serverdesk.abrit.cloud";
pub const SERVER_KEY: &str = "XDQrtTIvt+ISB6Zp8iqpjNpwmjRmkfpLHilOsBmrZHM=";

pub fn owns_service_executable(exe: &str) -> bool {
    let parts: Vec<_> = exe.split(['\\', '/']).collect();
    parts.last().is_some_and(|name| name.eq_ignore_ascii_case("AbritDesk.exe"))
        && !parts.iter().any(|name| name.eq_ignore_ascii_case("RustDesk"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn service_binary_cannot_target_stock_or_legacy_installation() {
        for path in [r"C:\Program Files\AbritDesk\AbritDesk.exe", r"C:\My Tools\abritdesk.exe", "C:/Program Files/AbritDesk/ABRITDESK.EXE"] {
            assert!(owns_service_executable(path), "{path}");
        }
        for path in [r"C:\Program Files\RustDesk\RustDesk.exe", r"C:\Program Files\RustDesk\AbritDesk.exe", r"C:\Program Files\rustdesk\abritdesk.exe", r"C:\AbritDesk\RustDesk.exe", r"C:\AbritDesk\AbritDesk.exe --service", ""] {
            assert!(!owns_service_executable(path), "{path}");
        }
    }

    #[test]
    fn application_and_service_identity_are_independent() {
        assert_eq!(APP_NAME, "AbritDesk");
        assert_eq!(SERVICE_DISPLAY_NAME, format!("{APP_NAME} Service"));
        assert_ne!(APP_NAME.to_lowercase(), "rustdesk");
        assert_eq!(SERVER, "serverdesk.abrit.cloud");
        assert_eq!(SERVER_KEY.len(), 44);
    }
}
