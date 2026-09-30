use hbb_common::{config::{self, LocalConfig}, log};
use serde::Deserialize;

#[derive(Deserialize)]
struct ProductConfig {
    app_name: String,
    id_server: String,
    relay_server: String,
    public_key: String,
    default_language: String,
    default_theme: String,
}

pub fn initialize() {
    // This profile is compiled into the binary; runtime files cannot replace policy.
    let profile = serde_json::from_str::<ProductConfig>(include_str!(
        "../flutter/assets/abrit_config.json"
    ));
    let profile = match profile {
        Ok(profile) => profile,
        Err(error) => {
            log::error!("Invalid compiled abritDesk profile: {error}");
            std::process::exit(1);
        }
    };
    *config::APP_NAME.write().unwrap() = profile.app_name;
    let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
    settings.insert("custom-rendezvous-server".into(), profile.id_server);
    settings.insert("relay-server".into(), profile.relay_server);
    settings.insert("key".into(), profile.public_key);
    settings.insert("api-server".into(), String::new());
    drop(settings);

    // A marker distinguishes first use from a later choice of system language.
    if LocalConfig::get_option("abrit-first-run-complete").is_empty() {
        if LocalConfig::get_option("lang").is_empty() {
            LocalConfig::set_option("lang".into(), profile.default_language);
        }
        if LocalConfig::get_option("theme").is_empty() {
            LocalConfig::set_option("theme".into(), profile.default_theme);
        }
        LocalConfig::set_option("abrit-first-run-complete".into(), "Y".into());
    }
}
