pub const APP_NAME: &str = "AbritDesk";
pub const SERVICE_DISPLAY_NAME: &str = "AbritDesk Service";
pub const SERVER: &str = "serverdesk.abrit.cloud";
pub const SERVER_KEY: &str = "XDQrtTIvt+ISB6Zp8iqpjNpwmjRmkfpLHilOsBmrZHM=";

pub fn installation_mode(arg: &str) -> bool {
    matches!(arg, "--install" | "--silent-install" | "--update" | "--uninstall"
        | "--after-install" | "--before-uninstall" | "--install-service" | "--uninstall-service")
}

// Inputs are canonical paths; normalize Windows spelling, not filesystem aliases.
pub fn runtime_path_key(path: &str) -> String {
    let path = path.replace('/', "\\");
    let path = if let Some(unc) = path.strip_prefix(r"\\?\UNC\") {
        format!(r"\\{}", unc)
    } else {
        path.strip_prefix(r"\\?\").unwrap_or(&path).to_owned()
    };
    path.to_lowercase()
}

pub fn needs_private_runtime(current: &str, installed: Option<&str>, installation: bool) -> bool {
    !installation && installed.is_some_and(|installed| runtime_path_key(current) != runtime_path_key(installed))
}

pub fn owns_service_executable(exe: &str) -> bool {
    let parts: Vec<_> = exe.split(['\\', '/']).collect();
    parts.last().is_some_and(|name| name.eq_ignore_ascii_case("AbritDesk.exe"))
        && !parts.iter().any(|name| name.eq_ignore_ascii_case("RustDesk"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn portable_coexistence_requires_another_installed_binary() {
        let installed = r"C:\Program Files\AbritDesk\AbritDesk.exe";
        let portable = r"C:\Users\tester\AppData\Local\abritdesk\AbritDesk.exe";
        assert!(needs_private_runtime(portable, Some(installed), false));
        assert!(!needs_private_runtime(installed, Some(installed), false));
        assert!(!needs_private_runtime(portable, None, false));
        assert!(!needs_private_runtime(portable, Some(installed), true));
    }

    #[test]
    fn canonical_windows_path_spellings_share_one_runtime_key() {
        let installed = r"C:\Program Files\AbritDesk\AbritDesk.exe";
        for same in [r"\\?\C:\Program Files\AbritDesk\AbritDesk.exe", "c:/program files/abritdesk/ABRITDESK.EXE"] {
            assert_eq!(runtime_path_key(same), runtime_path_key(installed));
            assert!(!needs_private_runtime(same, Some(installed), false));
        }
        assert_eq!(runtime_path_key(r"\\?\UNC\Host\Share\AbritDesk.exe"), runtime_path_key(r"\\host\share\abritdesk.exe"));
        assert_ne!(runtime_path_key(r"C:\A\AbritDesk.exe"), runtime_path_key(r"C:\B\AbritDesk.exe"));
    }

    #[test]
    fn runtime_children_do_not_become_installation_commands() {
        for arg in ["", "--cm", "--server", "--portable-service", "--elevate", "--run-as-system", "--tray", "--identity-json", "--connection-status-json", "--noinstall"] {
            assert!(!installation_mode(arg), "{arg}");
        }
        for arg in ["--install", "--silent-install", "--update", "--uninstall", "--after-install", "--before-uninstall", "--install-service", "--uninstall-service"] {
            assert!(installation_mode(arg), "{arg}");
        }
    }

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
