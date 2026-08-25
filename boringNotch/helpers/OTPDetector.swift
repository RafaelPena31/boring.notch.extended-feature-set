//
//  OTPDetector.swift
//  boringNotch
//

import Foundation

enum OTPDetector {
    private static let keywordWindow = 40
    private static let keywords = [
        "verification", "one-time", "one time", "passcode", "otp",
        "security code", "confirmation code", "confirmation", "access code",
        "auth code", "authentication code", "two-factor", "2fa", "pin", "code"
    ]
    private static let strongKeywords = [
        "verification", "one-time", "one time", "passcode", "otp",
        "security code", "confirmation code", "access code", "auth code",
        "authentication code", "two-factor", "2fa"
    ]
    private static let digitRegex = try! NSRegularExpression(
        pattern: #"\d{3}[-\s]\d{3}\b|\b\d{4,8}\b"#
    )
    private static let alphanumericRegex = try! NSRegularExpression(
        pattern: #"\b(?=[A-Z0-9]*\d)(?=[A-Z0-9]*[A-Z])[A-Z0-9]{5,8}\b"#
    )

    static func detect(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)

        for match in digitRegex.matches(in: text, range: fullRange)
            where !isExcluded(match.range, in: source)
                && hasNearbyKeyword(match.range, in: source, keywords: keywords)
        {
            return source.substring(with: match.range)
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
        }

        for match in alphanumericRegex.matches(in: text, range: fullRange)
            where hasNearbyKeyword(match.range, in: source, keywords: strongKeywords)
        {
            return source.substring(with: match.range)
        }
        return nil
    }

    private static func isExcluded(_ range: NSRange, in text: NSString) -> Bool {
        let before = range.location > 0
            ? UnicodeScalar(text.character(at: range.location - 1)).map(Character.init)
            : nil
        let end = range.location + range.length
        let after = end < text.length
            ? UnicodeScalar(text.character(at: end)).map(Character.init)
            : nil

        if let before, "$€£¥₹".contains(before) { return true }
        if after == "%" || after == ":" || before == ":" { return true }
        if after == ".", end + 1 < text.length,
           Character(UnicodeScalar(text.character(at: end + 1))!).isNumber
        {
            return true
        }
        return false
    }

    private static func hasNearbyKeyword(
        _ range: NSRange,
        in text: NSString,
        keywords: [String]
    ) -> Bool {
        let start = max(0, range.location - keywordWindow)
        let end = min(text.length, range.location + range.length + keywordWindow)
        let window = text.substring(
            with: NSRange(location: start, length: end - start)
        ).lowercased()
        return keywords.contains { window.contains($0) }
    }
}
