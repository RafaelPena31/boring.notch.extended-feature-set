//
//  MeetingLinkDetector.swift
//  boringNotch
//

import Foundation

enum MeetingLinkDetector {
    static func detect(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        if let url, let meeting = classify(url) { return meeting }
        if let location, let meeting = firstLink(in: location) { return meeting }
        if let notes, let meeting = firstLink(in: notes) { return meeting }
        return nil
    }

    static func firstLink(in text: String) -> MeetingLink? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(
                types: NSTextCheckingResult.CheckingType.link.rawValue
              )
        else { return nil }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var result: MeetingLink?
        detector.enumerateMatches(in: text, options: [], range: range) { match, _, stop in
            guard let url = match?.url, let meeting = classify(url) else { return }
            result = meeting
            stop.pointee = true
        }
        return result
    }

    static func classify(_ candidate: URL) -> MeetingLink? {
        guard var components = URLComponents(url: candidate, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.user == nil,
              components.password == nil,
              let host = components.host?.lowercased(),
              let provider = MeetingProvider.provider(forHost: host),
              !components.path.isEmpty,
              components.path != "/"
        else { return nil }

        components.scheme = scheme
        components.host = host
        if (scheme == "https" && components.port == 443)
            || (scheme == "http" && components.port == 80)
        {
            components.port = nil
        }

        guard let normalizedURL = components.url else { return nil }
        return MeetingLink(url: normalizedURL, provider: provider)
    }
}
