use super::model::{access_blocked, cached_manifest, is_https, Manifest};
use hbb_common::{config::LocalConfig, log};
use serde_json::{json, Value};
use std::{
    io::Read,
    sync::{atomic::{AtomicBool, Ordering}, Condvar, Mutex, Once, RwLock},
    time::Duration,
};

const API: &str = match option_env!("ABRIT_CLIENT_API") { Some(url) => url, None => "" };
const CACHE_KEY: &str = "abrit-control-cache-v1";
static STARTED: Once = Once::new();
static BLOCKED: AtomicBool = AtomicBool::new(true);
static WAKE: Condvar = Condvar::new();
static REFRESH: Mutex<bool> = Mutex::new(false);
lazy_static::lazy_static! {
    static ref SNAPSHOT: RwLock<Value> = RwLock::new(json!({
        "enabled": super::enabled(), "checking": super::enabled(),
        "blocked": super::enabled(), "current_version": crate::VERSION,
        "document": null, "error": false
    }));
}
pub fn blocked() -> bool { BLOCKED.load(Ordering::Acquire) }
pub fn snapshot() -> String {
    if super::enabled() { start(); }
    match SNAPSHOT.read() {
        Ok(value) => value.to_string(),
        Err(error) => {
            log::error!("abritdesk policy state lock: {error}");
            json!({"enabled": super::enabled(), "checking": false,
                "blocked": super::enabled(), "current_version": crate::VERSION,
                "document": null, "error": true}).to_string()
        }
    }
}
pub fn refresh() {
    if !super::enabled() { return; }
    start();
    if let Ok(mut requested) = REFRESH.lock() {
        *requested = true;
        WAKE.notify_one();
    }
}
fn publish(manifest: Option<&Manifest>, checking: bool, error: bool) {
    let blocked = access_blocked(manifest, crate::VERSION, checking,
        option_env!("ABRIT_CLIENT_FAIL_CLOSED") == Some("true"));
    BLOCKED.store(blocked, Ordering::Release);
    match SNAPSHOT.write() {
        Ok(mut value) => *value = json!({
            "enabled": true, "checking": checking, "blocked": blocked,
            "current_version": crate::VERSION, "document": manifest, "error": error
        }),
        Err(error) => log::error!("abritdesk policy state lock: {error}"),
    }
}
pub fn start() {
    STARTED.call_once(|| {
        let cached = LocalConfig::get_option(CACHE_KEY);
        let manifest = cached_manifest(&cached, API);
        publish(manifest.as_ref(), manifest.is_none(), false);
        if let Err(error) = std::thread::Builder::new().name("abritdesk-policy".into())
            .spawn(move || worker(manifest))
        {
            log::error!("abritdesk policy worker: {error}");
            publish(None, true, true);
        }
    });
}
fn fetch(client: &reqwest::blocking::Client, etag: &str) -> Result<Option<(Manifest, String)>, String> {
    if !is_https(API) { return Err("Policy API requires HTTPS".to_owned()); }
    let mut request = client.get(API)
        .query(&[("platform", "windows"), ("arch", "x64"), ("version", crate::VERSION)])
        .header("Cache-Control", "no-cache");
    if !etag.is_empty() { request = request.header("If-None-Match", etag); }
    let response = request.send().map_err(|e| e.to_string())?;
    if response.status() == reqwest::StatusCode::NOT_MODIFIED { return Ok(None); }
    let response = response.error_for_status().map_err(|e| e.to_string())?;
    let etag = response.headers().get("etag").and_then(|v| v.to_str().ok()).unwrap_or("").to_owned();
    let mut bytes = Vec::new();
    response.take(65537).read_to_end(&mut bytes).map_err(|e| e.to_string())?;
    let raw = String::from_utf8(bytes).map_err(|e| e.to_string())?;
    Ok(Some((Manifest::parse(&raw)?, etag)))
}
fn worker(mut manifest: Option<Manifest>) {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(8))
        // Re-resolve the stable API domain when moving the server through DNS.
        .pool_max_idle_per_host(0)
        .user_agent(concat!("abritdesk/", env!("CARGO_PKG_VERSION")))
        .redirect(reqwest::redirect::Policy::custom(|attempt| {
            if attempt.url().scheme() != "https" || attempt.previous().len() >= 3 {
                attempt.stop()
            } else { attempt.follow() }
        })).build();
    let client = match client {
        Ok(client) => client,
        Err(error) => {
            log::error!("abritdesk policy HTTP client: {error}");
            publish(manifest.as_ref(), false, true);
            return;
        }
    };
    let mut etag = String::new();
    loop {
        match fetch(&client, &etag) {
            Ok(Some((fresh, new_etag))) => {
                let cache = json!({"api": API, "document": &fresh}).to_string();
                if LocalConfig::get_option(CACHE_KEY) != cache {
                    LocalConfig::set_option(CACHE_KEY.to_owned(), cache);
                }
                manifest = Some(fresh);
                etag = new_etag;
                publish(manifest.as_ref(), false, false);
            }
            Ok(None) if manifest.is_some() => publish(manifest.as_ref(), false, false),
            Ok(None) => publish(None, false, true),
            Err(error) => {
                log::warn!("abritdesk policy refresh: {error}");
                publish(manifest.as_ref(), false, true);
            }
        }
        let seconds = manifest.as_ref().map_or(30, Manifest::poll_seconds);
        match REFRESH.lock() {
            Ok(mut requested) => {
                if !*requested {
                    match WAKE.wait_timeout(requested, Duration::from_secs(seconds)) {
                        Ok((guard, _)) => requested = guard,
                        Err(error) => { log::error!("abritdesk policy wake lock: {error}"); return; }
                    }
                }
                *requested = false;
            }
            Err(error) => { log::error!("abritdesk policy refresh lock: {error}"); return; }
        }
        std::thread::park_timeout(Duration::from_secs(1));
    }
}
