use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Update {
    pub latest_version: String,
    #[serde(default = "minimum_default")]
    pub minimum_version: String,
    pub download_url: String,
    #[serde(default)]
    pub mandatory: bool,
    #[serde(default)]
    pub message: Value,
}

fn minimum_default() -> String { "0.0.0".to_owned() }

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Manifest {
    pub schema_version: u32,
    pub revision: String,
    #[serde(default = "poll_default")]
    pub poll_interval_seconds: u64,
    #[serde(default)]
    pub banner: Option<Value>,
    #[serde(default)]
    pub update: Option<Update>,
}

fn poll_default() -> u64 { 30 }

pub fn cached_manifest(raw: &str, api: &str) -> Option<Manifest> {
    let cache: Value = serde_json::from_str(raw).ok()?;
    if cache["api"].as_str() != Some(api) { return None; }
    Manifest::parse(&cache["document"].to_string()).ok()
}

pub fn access_blocked(manifest: Option<&Manifest>, current: &str,
    checking: bool, fail_closed: bool) -> bool {
    manifest.map(|m| m.blocked(current).unwrap_or(true)).unwrap_or(checking || fail_closed)
}

pub fn version(value: &str) -> Result<[u32; 3], String> {
    let mut result = [0; 3];
    let parts: Vec<_> = value.split('.').collect();
    if parts.is_empty() || parts.len() > 3 { return Err("Invalid release version".to_owned()); }
    for (index, part) in parts.iter().enumerate() {
        if part.is_empty() || !part.bytes().all(|byte| byte.is_ascii_digit()) {
            return Err("Invalid release version".to_owned());
        }
        result[index] = part.parse().map_err(|_| "Invalid release version")?;
    }
    Ok(result)
}

pub fn is_https(value: &str) -> bool {
    value.starts_with("https://") && value.len() <= 2048
        && !value.chars().any(|c| c.is_whitespace() || c.is_control())
        && value[8..].split('/').next().is_some_and(|host| {
            !host.is_empty() && !host.contains('@') && !host.contains('\\')
        })
}

impl Manifest {
    pub fn parse(raw: &str) -> Result<Self, String> {
        if raw.len() > 64 * 1024 { return Err("Manifest exceeds 64 KiB".to_owned()); }
        let manifest: Self = serde_json::from_str(raw).map_err(|e| e.to_string())?;
        if manifest.schema_version != 1 || manifest.revision.len() > 200 {
            return Err("Unsupported manifest schema or revision".to_owned());
        }
        if let Some(update) = &manifest.update {
            if version(&update.minimum_version)? > version(&update.latest_version)? || !is_https(&update.download_url) {
                return Err("Invalid update policy".to_owned());
            }
        }
        if let Some(banner) = &manifest.banner {
            if !banner.is_object() { return Err("Invalid banner".to_owned()); }
            for key in ["image_url", "image_url_dark", "link_url"] {
                if let Some(value) = banner.get(key) {
                    if !value.is_null() && !value.as_str().is_some_and(|s| s.is_empty() || is_https(s)) {
                        return Err(format!("Invalid banner {key}"));
                    }
                }
            }
            if let Some(enabled) = banner.get("enabled") {
                if !enabled.is_boolean() { return Err("Invalid banner visibility".to_owned()); }
            }
        }
        Ok(manifest)
    }

    pub fn blocked(&self, current: &str) -> Result<bool, String> {
        let current = version(current)?;
        match &self.update {
            Some(update) => Ok(current < version(&update.minimum_version)?
                || (update.mandatory && current < version(&update.latest_version)?)),
            None => Ok(false),
        }
    }

    pub fn poll_seconds(&self) -> u64 { self.poll_interval_seconds.clamp(5, 300) }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn manifest(minimum: &str, latest: &str, mandatory: bool) -> Manifest {
        Manifest::parse(&serde_json::json!({"schema_version":1,"revision":"test",
            "update":{"minimum_version":minimum,"latest_version":latest,"mandatory":mandatory,
            "download_url":"https://abritdesk.ir/download"}}).to_string()).unwrap()
    }
    #[test]
    fn compares_numeric_versions() {
        assert!(version("1.10").unwrap() > version("1.9.9").unwrap());
        assert_eq!(version("1.3").unwrap(), version("1.3.0").unwrap());
        for invalid in ["", "1.-1", "1.x", "1.2.3.4", "1.2-beta", "99999999999"] {
            assert!(version(invalid).is_err());
        }
    }
    #[test]
    fn distinguishes_optional_minimum_and_mandatory() {
        let optional = manifest("1.2", "1.4", false);
        assert!(!optional.blocked("1.3").unwrap());
        assert!(optional.blocked("1.1").unwrap());
        assert!(!optional.blocked("1.2").unwrap());
        assert!(manifest("1.2", "1.4", true).blocked("1.3").unwrap());
        assert!(!manifest("1.2", "1.4", true).blocked("1.4").unwrap());
        assert!(!manifest("1.2", "1.4", true).blocked("2.0").unwrap());
    }
    #[test]
    fn rejects_invalid_policies_and_links() {
        assert!(Manifest::parse(r#"{"schema_version":2,"revision":"x"}"#).is_err());
        assert!(Manifest::parse(&"x".repeat(65537)).is_err());
        for url in ["http://host/a", "file:///x", "https://", "https://user@host/a", "https://host/ a"] {
            assert!(!is_https(url));
        }
        assert!(Manifest::parse(r#"{"schema_version":1,"revision":"x","update":{"minimum_version":"2","latest_version":"1","download_url":"https://example.com/a"}}"#).is_err());
    }
    #[test]
    fn supports_banner_only_and_bounds_refresh() {
        let mut value = Manifest::parse(r#"{"schema_version":1,"revision":"b","banner":{"enabled":false}}"#).unwrap();
        assert!(!value.blocked("1.3").unwrap());
        value.poll_interval_seconds = 0;
        assert_eq!(value.poll_seconds(), 5);
        value.poll_interval_seconds = 99999;
        assert_eq!(value.poll_seconds(), 300);
    }

    #[test]
    fn keeps_cached_requirement_during_outage_and_binds_cache_to_endpoint() {
        let policy = manifest("1.3", "1.4", false);
        let cache = serde_json::json!({"api":"https://abritdesk.ir/api","document":policy}).to_string();
        let saved = cached_manifest(&cache, "https://abritdesk.ir/api");
        assert!(access_blocked(saved.as_ref(), "1.2", false, false));
        assert!(!access_blocked(saved.as_ref(), "1.3", false, false));
        assert!(cached_manifest(&cache, "https://another.example/api").is_none());
        assert!(cached_manifest("broken", "https://abritdesk.ir/api").is_none());
    }

    #[test]
    fn first_check_blocks_but_initial_outage_can_allow_use() {
        assert!(access_blocked(None, "1.5.1", true, false));
        assert!(!access_blocked(None, "1.5.1", false, false));
        assert!(access_blocked(None, "1.5.1", false, true));
        assert!(access_blocked(Some(&manifest("1.6", "1.6", false)), "1.5.1", false, false));
    }
}
