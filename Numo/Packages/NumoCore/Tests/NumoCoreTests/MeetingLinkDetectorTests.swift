import Foundation
import Testing

@testable import NumoCore

struct DetectionCase: Sendable, CustomTestStringConvertible {
    let name: String
    var url: String?
    var location: String?
    var notes: String?
    let platform: MeetingPlatform?
    var expectedURL: String?

    var testDescription: String { name }
}

private let detectionCases: [DetectionCase] = [
    DetectionCase(
        name: "Meet link in the event url",
        url: "https://meet.google.com/abc-defg-hij",
        platform: .googleMeet,
        expectedURL: "https://meet.google.com/abc-defg-hij"
    ),
    DetectionCase(
        name: "Meet link in notes, trailing sentence dot trimmed",
        notes: "Join here: https://meet.google.com/abc-defg-hij?hs=224.",
        platform: .googleMeet,
        expectedURL: "https://meet.google.com/abc-defg-hij?hs=224"
    ),
    DetectionCase(
        name: "Meet link inside an HTML anchor",
        notes: #"<a href="https://meet.google.com/abc-defg-hij?authuser=0">Join</a>"#,
        platform: .googleMeet,
        expectedURL: "https://meet.google.com/abc-defg-hij?authuser=0"
    ),
    DetectionCase(
        name: "HTML-escaped ampersand is decoded",
        notes: "https://meet.google.com/abc-defg-hij?a=1&amp;b=2",
        platform: .googleMeet,
        expectedURL: "https://meet.google.com/abc-defg-hij?a=1&b=2"
    ),
    DetectionCase(
        name: "Meet link in location",
        location: "https://meet.google.com/abc-defg-hij",
        platform: .googleMeet
    ),
    DetectionCase(
        name: "Classic Teams meetup-join link",
        notes: "Join: https://teams.microsoft.com/l/meetup-join/19%3ameeting_ABC%40thread.v2/0?context=%7b%22Tid%22%3a%22x%22%7d",
        platform: .microsoftTeams
    ),
    DetectionCase(
        name: "New-style Teams /meet/ link",
        notes: "https://teams.microsoft.com/meet/123456789012?p=abcDEF",
        platform: .microsoftTeams
    ),
    DetectionCase(
        name: "Personal Teams (teams.live.com) link",
        notes: "https://teams.live.com/meet/9876543210",
        platform: .microsoftTeams
    ),
    DetectionCase(
        name: "Outlook Safe Links wrapper is unwrapped",
        notes: "https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Fteams.microsoft.com%2Fl%2Fmeetup-join%2F19%253ameeting_X%2540thread.v2%2F0&data=05",
        platform: .microsoftTeams
    ),
    DetectionCase(
        name: "Earlier field wins between Meet and Teams",
        location: "https://meet.google.com/aaa-bbbb-ccc",
        notes: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_X%40thread.v2/0",
        platform: .googleMeet
    ),
    DetectionCase(
        name: "Meet/Teams beat Zoom even when Zoom is listed first",
        notes: "Zoom: https://acme.zoom.us/j/123456789 or Teams: https://teams.live.com/meet/555",
        platform: .microsoftTeams
    ),
    DetectionCase(
        name: "Zoom is used when it is the only provider",
        notes: "https://acme.zoom.us/j/123456789?pwd=abc",
        platform: .zoom
    ),
    DetectionCase(
        name: "Look-alike host is rejected",
        url: "https://meet.google.com.evil.example/abc-defg-hij",
        platform: nil
    ),
    DetectionCase(
        name: "Real link only appearing in another site's query is rejected",
        notes: "https://evil.example/?u=https://meet.google.com/abc-defg-hij",
        platform: nil
    ),
    DetectionCase(
        name: "Zoom look-alike is rejected",
        notes: "https://notzoom.us/j/123",
        platform: nil
    ),
    DetectionCase(
        name: "Bare Meet landing page is not a meeting",
        notes: "https://meet.google.com/",
        platform: nil
    ),
    DetectionCase(
        name: "Ordinary document link is ignored",
        notes: "Agenda: https://docs.google.com/document/d/1abc/edit",
        platform: nil
    ),
    DetectionCase(
        name: "Plain text without any link",
        location: "Conference room 4",
        notes: "Bring the slides",
        platform: nil
    ),
]

struct MeetingLinkDetectorTests {
    @Test("Detects the right provider", arguments: detectionCases)
    func detects(_ testCase: DetectionCase) {
        let link = MeetingLinkDetector().detect(
            url: testCase.url,
            location: testCase.location,
            notes: testCase.notes
        )
        #expect(link?.platform == testCase.platform)
        if let expected = testCase.expectedURL {
            #expect(link?.url.absoluteString == expected)
        }
    }

    @Test func allNilInputsYieldNothing() {
        #expect(MeetingLinkDetector().detect(url: nil, location: nil, notes: nil) == nil)
    }
}

struct TeamsDeepLinkTests {
    @Test func classicLinkBecomesMsteamsScheme() throws {
        let native = try #require(TeamsDeepLink.nativeURL(for: teamsLink))
        #expect(native.scheme == "msteams")
        #expect(native.host == "teams.microsoft.com")
        #expect(native.path == teamsLink.url.path)
    }

    @Test func newStyleLinkStaysOnHttps() {
        let link = MeetingLink(url: URL(string: "https://teams.microsoft.com/meet/123?p=a")!, platform: .microsoftTeams)
        #expect(TeamsDeepLink.nativeURL(for: link) == nil)
    }

    @Test func otherProvidersAreNotRewritten() {
        #expect(TeamsDeepLink.nativeURL(for: meetLink) == nil)
    }
}
