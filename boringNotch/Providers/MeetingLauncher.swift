//
//  MeetingLauncher.swift
//  boringNotch
//

import AppKit
import Foundation

enum MeetingLauncher {
    static func open(_ meeting: MeetingLink) {
        let workspace = NSWorkspace.shared

        if let nativeURL = nativeURL(for: meeting),
            workspace.urlForApplication(toOpen: nativeURL) != nil,
            workspace.open(nativeURL)
        {
            return
        }

        workspace.open(meeting.url)
    }

    private static func nativeURL(for meeting: MeetingLink) -> URL? {
        switch meeting.provider {
        case .zoom:
            zoomURL(from: meeting.url)
        case .teams:
            teamsURL(from: meeting.url)
        case .googleMeet, .webex, .whereby, .jitsi:
            nil
        }
    }

    private static func zoomURL(from url: URL) -> URL? {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let host = source.host
        else { return nil }

        let pathComponents = source.path.split(separator: "/").map(String.init)
        guard pathComponents.count >= 2, pathComponents[0].lowercased() == "j" else {
            return nil
        }

        let meetingNumber = pathComponents[1]
        guard !meetingNumber.isEmpty, meetingNumber.allSatisfy({ $0.isNumber }) else {
            return nil
        }

        var queryItems = [
            URLQueryItem(name: "action", value: "join"),
            URLQueryItem(name: "confno", value: meetingNumber),
        ]
        if let password = source.queryItems?.first(where: {
            $0.name.caseInsensitiveCompare("pwd") == .orderedSame
        })?.value, !password.isEmpty {
            queryItems.append(URLQueryItem(name: "pwd", value: password))
        }

        var destination = URLComponents()
        destination.scheme = "zoommtg"
        destination.host = host
        destination.path = "/join"
        destination.queryItems = queryItems
        return destination.url
    }

    private static func teamsURL(from url: URL) -> URL? {
        guard var destination = URLComponents(url: url, resolvingAgainstBaseURL: false),
            destination.host != nil
        else { return nil }

        destination.scheme = "msteams"
        return destination.url
    }
}
