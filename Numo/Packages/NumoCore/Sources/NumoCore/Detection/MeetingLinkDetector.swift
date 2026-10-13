import Foundation

/// Finds a Google Meet / Microsoft Teams / Zoom join link in an event's url, location and notes.
///
/// Rules:
/// - Only https/http URLs on an exact, known host count. `meet.google.com.evil.example` does not.
/// - Fields are searched in the order url, location, notes; the first Meet/Teams link wins.
/// - A Zoom link is only returned when no Meet/Teams link exists anywhere.
/// - Outlook "Safe Links" wrappers are unwrapped before classification.
public struct MeetingLinkDetector: Sendable {
    public init() {}

    public func detect(url: String?, location: String?, notes: String?) -> MeetingLink? {
        var firstZoom: MeetingLink?
        for text in [url, location, notes].compactMap({ $0 }) {
            for candidate in Self.urlCandidates(in: text) {
                guard let link = Self.classify(candidate) else { continue }
                if link.platform == .zoom {
                    firstZoom = firstZoom ?? link
                } else {
                    return link
                }
            }
        }
        return firstZoom
    }

    // MARK: - Extraction

    static func urlCandidates(in rawText: String) -> [URL] {
        let text = decodeEntities(rawText)
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"']+"#, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            var candidate = String(text[r])
            while let last = candidate.last, ".,;:!?)]}>".contains(last) {
                candidate.removeLast()
            }
            guard let url = URL(string: candidate) else { return nil }
            return unwrapSafeLink(url)
        }
    }

    /// Notes from some providers arrive HTML-escaped (`&amp;` in query strings, `&lt;a href=...`).
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    static func unwrapSafeLink(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(), host.hasSuffix(".safelinks.protection.outlook.com"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let target = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let unwrapped = URL(string: target)
        else { return url }
        return unwrapped
    }

    // MARK: - Classification

    static func classify(_ url: URL) -> MeetingLink? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased()
        else { return nil }
        let path = url.path

        switch host {
        case "meet.google.com":
            // A real meeting code, not the bare landing page.
            return path.count > 1 ? MeetingLink(url: url, platform: .googleMeet) : nil

        case "teams.microsoft.com":
            return path.hasPrefix("/l/meetup-join/") || path.hasPrefix("/meet/")
                ? MeetingLink(url: url, platform: .microsoftTeams) : nil

        case "teams.live.com":
            return path.hasPrefix("/meet/") ? MeetingLink(url: url, platform: .microsoftTeams) : nil

        case "teams.microsoft.us", "gov.teams.microsoft.us", "dod.teams.microsoft.us":
            return path.hasPrefix("/l/meetup-join/") ? MeetingLink(url: url, platform: .microsoftTeams) : nil

        default:
            if host == "zoom.us" || host.hasSuffix(".zoom.us") {
                let isJoinPath = ["/j/", "/my/", "/wc/join/"].contains { path.hasPrefix($0) }
                return isJoinPath ? MeetingLink(url: url, platform: .zoom) : nil
            }
            return nil
        }
    }
}

/// Opens Teams in the desktop app instead of the browser when possible.
public enum TeamsDeepLink {
    /// `msteams://` equivalent of a classic `/l/meetup-join/` link, or nil when we are not
    /// confident the native scheme understands the link (new-style `/meet/` links fall back to https
    /// until verified on hardware, see docs spike S5).
    public static func nativeURL(for link: MeetingLink) -> URL? {
        guard link.platform == .microsoftTeams,
              var components = URLComponents(url: link.url, resolvingAgainstBaseURL: false),
              components.host?.lowercased() == "teams.microsoft.com",
              components.path.hasPrefix("/l/meetup-join/")
        else { return nil }
        components.scheme = "msteams"
        return components.url
    }
}
