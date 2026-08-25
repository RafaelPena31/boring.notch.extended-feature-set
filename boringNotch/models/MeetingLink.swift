//
//  MeetingLink.swift
//  boringNotch
//

import Foundation

enum MeetingProvider: String, Codable, CaseIterable, Sendable {
    case googleMeet
    case zoom
    case teams
    case webex
    case whereby
    case jitsi

    var displayName: String {
        switch self {
        case .googleMeet: "Google Meet"
        case .zoom: "Zoom"
        case .teams: "Microsoft Teams"
        case .webex: "Webex"
        case .whereby: "Whereby"
        case .jitsi: "Jitsi"
        }
    }

    var hostSuffixes: [String] {
        switch self {
        case .googleMeet: ["meet.google.com", "hangouts.google.com"]
        case .zoom: ["zoom.us", "zoomgov.com"]
        case .teams: ["teams.microsoft.com", "teams.live.com"]
        case .webex: ["webex.com"]
        case .whereby: ["whereby.com"]
        case .jitsi: ["meet.jit.si"]
        }
    }

    static func provider(forHost host: String) -> MeetingProvider? {
        let normalizedHost = host.lowercased()
        return allCases.first { provider in
            provider.hostSuffixes.contains { suffix in
                normalizedHost == suffix || normalizedHost.hasSuffix(".\(suffix)")
            }
        }
    }
}

struct MeetingLink: Equatable, Codable, Sendable {
    let url: URL
    let provider: MeetingProvider

    var displayLabel: String { "Join \(provider.displayName)" }
    var symbolName: String { "video.fill" }
}
