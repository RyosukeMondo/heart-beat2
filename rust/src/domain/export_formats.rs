//! Export training sessions to standard fitness file formats (TCX, GPX).
//!
//! Provides pure functions for converting [`CompletedSession`] data into
//! Garmin-compatible TCX and standard GPX XML strings. No I/O is performed;
//! callers are responsible for writing the resulting strings to disk or network.

use chrono::SecondsFormat;

use crate::domain::session_history::CompletedSession;

// ---------------------------------------------------------------------------
// XML escaping
// ---------------------------------------------------------------------------

/// Escape special characters for safe embedding in XML text content.
fn xml_escape(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for ch in input.chars() {
        match ch {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&apos;"),
            _ => out.push(ch),
        }
    }
    out
}

// ---------------------------------------------------------------------------
// TCX export
// ---------------------------------------------------------------------------

/// Format a single `<Trackpoint>` element for TCX output.
fn write_tcx_trackpoint(buf: &mut String, time_iso: &str, bpm: u16) {
    buf.push_str("          <Trackpoint>\n");
    buf.push_str(&format!("            <Time>{time_iso}</Time>\n"));
    buf.push_str("            <HeartRateBpm>");
    buf.push_str(&format!("<Value>{bpm}</Value>"));
    buf.push_str("</HeartRateBpm>\n");
    buf.push_str("          </Trackpoint>\n");
}

/// Format the `<Lap>` element (including the inner `<Track>`) for TCX output.
fn write_tcx_lap(session: &CompletedSession) -> String {
    let start_iso = session
        .start_time
        .to_rfc3339_opts(SecondsFormat::Secs, true);
    let summary = &session.summary;

    let mut buf = String::new();
    buf.push_str(&format!("    <Lap StartTime=\"{start_iso}\">\n"));
    buf.push_str(&format!(
        "      <TotalTimeSeconds>{}</TotalTimeSeconds>\n",
        summary.duration_secs
    ));
    buf.push_str("      <DistanceMeters>0</DistanceMeters>\n");
    buf.push_str(&format!(
        "      <MaximumHeartRateBpm><Value>{}</Value></MaximumHeartRateBpm>\n",
        summary.max_hr
    ));
    buf.push_str(&format!(
        "      <AverageHeartRateBpm><Value>{}</Value></AverageHeartRateBpm>\n",
        summary.avg_hr
    ));
    buf.push_str("      <Calories>0</Calories>\n");
    buf.push_str("      <Intensity>Active</Intensity>\n");
    buf.push_str("      <TriggerMethod>Manual</TriggerMethod>\n");

    if !session.hr_samples.is_empty() {
        buf.push_str("      <Track>\n");
        for sample in &session.hr_samples {
            let ts = sample.timestamp.to_rfc3339_opts(SecondsFormat::Secs, true);
            write_tcx_trackpoint(&mut buf, &ts, sample.bpm);
        }
        buf.push_str("      </Track>\n");
    }

    buf.push_str("    </Lap>\n");
    buf
}

/// Export a completed session as a Garmin-compatible TCX XML string.
///
/// The output conforms to the TrainingCenterDatabase v2 schema and can be
/// imported into Garmin Connect, Strava, and other fitness platforms.
pub fn export_to_tcx(session: &CompletedSession) -> String {
    let start_iso = session
        .start_time
        .to_rfc3339_opts(SecondsFormat::Secs, true);
    let plan_escaped = xml_escape(&session.plan_name);

    let mut xml = String::new();
    xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    xml.push_str("<TrainingCenterDatabase xmlns=\"http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2\">\n");
    xml.push_str("  <Activities>\n");
    xml.push_str("    <Activity Sport=\"Other\">\n");
    xml.push_str(&format!("      <Id>{start_iso}</Id>\n"));
    xml.push_str(&write_tcx_lap(session));
    xml.push_str(&format!("      <Notes>{plan_escaped}</Notes>\n"));
    xml.push_str("    </Activity>\n");
    xml.push_str("  </Activities>\n");
    xml.push_str("</TrainingCenterDatabase>\n");
    xml
}

// ---------------------------------------------------------------------------
// GPX export
// ---------------------------------------------------------------------------

/// Format a single `<trkpt>` element for GPX output.
fn write_gpx_trackpoint(buf: &mut String, time_iso: &str, bpm: u16) {
    buf.push_str("      <trkpt>\n");
    buf.push_str(&format!("        <time>{time_iso}</time>\n"));
    buf.push_str("        <extensions>");
    buf.push_str(&format!("<hr>{bpm}</hr>"));
    buf.push_str("</extensions>\n");
    buf.push_str("      </trkpt>\n");
}

/// Export a completed session as a GPX 1.1 XML string.
///
/// Produces a minimal GPX document with heart-rate data in `<extensions>`.
/// Suitable for import into tools that accept GPX with HR extensions.
pub fn export_to_gpx(session: &CompletedSession) -> String {
    let start_iso = session
        .start_time
        .to_rfc3339_opts(SecondsFormat::Secs, true);
    let plan_escaped = xml_escape(&session.plan_name);

    let mut xml = String::new();
    xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    xml.push_str("<gpx version=\"1.1\" creator=\"HeartBeat\">\n");
    xml.push_str("  <metadata>\n");
    xml.push_str(&format!("    <name>{plan_escaped}</name>\n"));
    xml.push_str(&format!("    <time>{start_iso}</time>\n"));
    xml.push_str("  </metadata>\n");
    xml.push_str("  <trk>\n");
    xml.push_str(&format!("    <name>{plan_escaped}</name>\n"));
    xml.push_str("    <trkseg>\n");

    for sample in &session.hr_samples {
        let ts = sample.timestamp.to_rfc3339_opts(SecondsFormat::Secs, true);
        write_gpx_trackpoint(&mut xml, &ts, sample.bpm);
    }

    xml.push_str("    </trkseg>\n");
    xml.push_str("  </trk>\n");
    xml.push_str("</gpx>\n");
    xml
}

// ===========================================================================
// Tests
// ===========================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session_history::{HrSample, SessionStatus, SessionSummary};
    use chrono::{TimeZone, Utc};

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /// Build a deterministic session with known timestamps for assertions.
    fn make_session(plan_name: &str, samples: Vec<HrSample>) -> CompletedSession {
        let start = Utc.with_ymd_and_hms(2025, 6, 15, 10, 0, 0).unwrap();
        let end = Utc.with_ymd_and_hms(2025, 6, 15, 10, 5, 0).unwrap();

        let (avg, max, min) = if samples.is_empty() {
            (0u16, 0u16, 0u16)
        } else {
            let bpms: Vec<u16> = samples.iter().map(|s| s.bpm).collect();
            let sum: u32 = bpms.iter().copied().map(u32::from).sum();
            let avg = (sum / bpms.len() as u32) as u16;
            let max = *bpms.iter().max().unwrap();
            let min = *bpms.iter().min().unwrap();
            (avg, max, min)
        };

        CompletedSession {
            id: "session-001".into(),
            plan_name: plan_name.into(),
            start_time: start,
            end_time: end,
            status: SessionStatus::Completed,
            hr_samples: samples,
            phases_completed: 3,
            summary: SessionSummary {
                duration_secs: 300,
                avg_hr: avg,
                max_hr: max,
                min_hr: min,
                time_in_zone: [60, 60, 60, 60, 60],
            },
        }
    }

    fn sample_at(offset_secs: i64, bpm: u16) -> HrSample {
        let ts = Utc.with_ymd_and_hms(2025, 6, 15, 10, 0, 0).unwrap()
            + chrono::Duration::seconds(offset_secs);
        HrSample { timestamp: ts, bpm }
    }

    fn normal_samples() -> Vec<HrSample> {
        vec![sample_at(0, 120), sample_at(60, 140), sample_at(120, 160)]
    }

    // -----------------------------------------------------------------------
    // xml_escape
    // -----------------------------------------------------------------------

    #[test]
    fn xml_escape_handles_all_special_chars() {
        assert_eq!(xml_escape("a&b"), "a&amp;b");
        assert_eq!(xml_escape("<tag>"), "&lt;tag&gt;");
        assert_eq!(xml_escape("he said \"hi\""), "he said &quot;hi&quot;");
        assert_eq!(xml_escape("it's"), "it&apos;s");
    }

    #[test]
    fn xml_escape_no_change_for_plain_text() {
        assert_eq!(xml_escape("Tempo Run"), "Tempo Run");
    }

    #[test]
    fn xml_escape_empty_string() {
        assert_eq!(xml_escape(""), "");
    }

    // -----------------------------------------------------------------------
    // TCX – normal session
    // -----------------------------------------------------------------------

    #[test]
    fn tcx_normal_session_has_xml_declaration() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.starts_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"));
    }

    #[test]
    fn tcx_normal_session_has_root_element() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("<TrainingCenterDatabase xmlns="));
        assert!(tcx.contains("</TrainingCenterDatabase>"));
    }

    #[test]
    fn tcx_normal_session_has_activity_with_sport() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("<Activity Sport=\"Other\">"));
    }

    #[test]
    fn tcx_normal_session_id_matches_start_time() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("<Id>2025-06-15T10:00:00Z</Id>"));
    }

    #[test]
    fn tcx_normal_session_lap_attributes() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("Lap StartTime=\"2025-06-15T10:00:00Z\""));
        assert!(tcx.contains("<TotalTimeSeconds>300</TotalTimeSeconds>"));
        assert!(tcx.contains("<DistanceMeters>0</DistanceMeters>"));
    }

    #[test]
    fn tcx_normal_session_hr_summary() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("<MaximumHeartRateBpm><Value>160</Value></MaximumHeartRateBpm>"));
        assert!(tcx.contains("<AverageHeartRateBpm><Value>140</Value></AverageHeartRateBpm>"));
    }

    #[test]
    fn tcx_normal_session_static_fields() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("<Calories>0</Calories>"));
        assert!(tcx.contains("<Intensity>Active</Intensity>"));
        assert!(tcx.contains("<TriggerMethod>Manual</TriggerMethod>"));
    }

    #[test]
    fn tcx_normal_session_trackpoints() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("<Track>"));
        assert!(tcx.contains("<Trackpoint>"));
        assert!(tcx.contains("<Time>2025-06-15T10:00:00Z</Time>"));
        assert!(tcx.contains("<HeartRateBpm><Value>120</Value></HeartRateBpm>"));
        assert!(tcx.contains("<HeartRateBpm><Value>140</Value></HeartRateBpm>"));
        assert!(tcx.contains("<HeartRateBpm><Value>160</Value></HeartRateBpm>"));
    }

    #[test]
    fn tcx_normal_session_notes() {
        let tcx = export_to_tcx(&make_session("Tempo", normal_samples()));
        assert!(tcx.contains("<Notes>Tempo</Notes>"));
    }

    // -----------------------------------------------------------------------
    // TCX – empty samples
    // -----------------------------------------------------------------------

    #[test]
    fn tcx_empty_samples_omits_track() {
        let tcx = export_to_tcx(&make_session("Empty Run", vec![]));
        assert!(!tcx.contains("<Track>"));
        assert!(!tcx.contains("<Trackpoint>"));
    }

    #[test]
    fn tcx_empty_samples_still_has_lap() {
        let tcx = export_to_tcx(&make_session("Empty Run", vec![]));
        assert!(tcx.contains("<Lap StartTime="));
        assert!(tcx.contains("<TotalTimeSeconds>300</TotalTimeSeconds>"));
    }

    // -----------------------------------------------------------------------
    // TCX – special characters
    // -----------------------------------------------------------------------

    #[test]
    fn tcx_special_chars_in_plan_name_are_escaped() {
        let tcx = export_to_tcx(&make_session(
            "Zone 3 <High> & \"Hard\" Run",
            normal_samples(),
        ));
        assert!(tcx.contains("<Notes>Zone 3 &lt;High&gt; &amp; &quot;Hard&quot; Run</Notes>"));
    }

    // -----------------------------------------------------------------------
    // GPX – normal session
    // -----------------------------------------------------------------------

    #[test]
    fn gpx_normal_session_has_xml_declaration() {
        let gpx = export_to_gpx(&make_session("Tempo", normal_samples()));
        assert!(gpx.starts_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"));
    }

    #[test]
    fn gpx_normal_session_has_root_element() {
        let gpx = export_to_gpx(&make_session("Tempo", normal_samples()));
        assert!(gpx.contains("<gpx version=\"1.1\" creator=\"HeartBeat\">"));
        assert!(gpx.contains("</gpx>"));
    }

    #[test]
    fn gpx_normal_session_metadata() {
        let gpx = export_to_gpx(&make_session("Tempo", normal_samples()));
        assert!(gpx.contains("<metadata>"));
        assert!(gpx.contains("<name>Tempo</name>"));
        assert!(gpx.contains("<time>2025-06-15T10:00:00Z</time>"));
    }

    #[test]
    fn gpx_normal_session_track_structure() {
        let gpx = export_to_gpx(&make_session("Tempo", normal_samples()));
        assert!(gpx.contains("<trk>"));
        assert!(gpx.contains("<trkseg>"));
        assert!(gpx.contains("</trkseg>"));
        assert!(gpx.contains("</trk>"));
    }

    #[test]
    fn gpx_normal_session_trackpoints() {
        let gpx = export_to_gpx(&make_session("Tempo", normal_samples()));
        assert!(gpx.contains("<trkpt>"));
        assert!(gpx.contains("<time>2025-06-15T10:00:00Z</time>"));
        assert!(gpx.contains("<extensions><hr>120</hr></extensions>"));
        assert!(gpx.contains("<extensions><hr>140</hr></extensions>"));
        assert!(gpx.contains("<extensions><hr>160</hr></extensions>"));
    }

    #[test]
    fn gpx_normal_session_track_name() {
        let gpx = export_to_gpx(&make_session("Tempo", normal_samples()));
        // Two <name> elements: one in metadata, one in trk
        let count = gpx.matches("<name>Tempo</name>").count();
        assert_eq!(count, 2);
    }

    // -----------------------------------------------------------------------
    // GPX – empty samples
    // -----------------------------------------------------------------------

    #[test]
    fn gpx_empty_samples_has_empty_trkseg() {
        let gpx = export_to_gpx(&make_session("Empty", vec![]));
        assert!(gpx.contains("<trkseg>\n    </trkseg>"));
        assert!(!gpx.contains("<trkpt>"));
    }

    // -----------------------------------------------------------------------
    // GPX – special characters
    // -----------------------------------------------------------------------

    #[test]
    fn gpx_special_chars_in_plan_name_are_escaped() {
        let gpx = export_to_gpx(&make_session(
            "Zone 3 <High> & \"Hard\" Run",
            normal_samples(),
        ));
        let escaped = "Zone 3 &lt;High&gt; &amp; &quot;Hard&quot; Run";
        assert!(gpx.contains(&format!("<name>{escaped}</name>")));
    }

    // -----------------------------------------------------------------------
    // Cross-format consistency
    // -----------------------------------------------------------------------

    #[test]
    fn both_formats_use_same_timestamps() {
        let session = make_session("Cross", normal_samples());
        let tcx = export_to_tcx(&session);
        let gpx = export_to_gpx(&session);

        // Both should contain the same ISO timestamps
        assert!(tcx.contains("2025-06-15T10:01:00Z"));
        assert!(gpx.contains("2025-06-15T10:01:00Z"));
    }

    #[test]
    fn both_formats_are_valid_utf8() {
        let session = make_session("UTF-8 test: cafe\u{0301}", normal_samples());
        let tcx = export_to_tcx(&session);
        let gpx = export_to_gpx(&session);

        // String type guarantees UTF-8, but let's verify encoding decl
        assert!(tcx.contains("encoding=\"UTF-8\""));
        assert!(gpx.contains("encoding=\"UTF-8\""));
    }
}
