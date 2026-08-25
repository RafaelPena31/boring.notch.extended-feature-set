import AppKit
import Contacts
import Defaults
import Foundation

@MainActor
final class ContactAvatarManager: ObservableObject {
    static let shared = ContactAvatarManager()

    @Published private(set) var authorizationStatus: CNAuthorizationStatus

    private let store = CNContactStore()
    private var imageCache: [String: NSImage?] = [:]

    private init() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Called only from the explicit Contacts control in notification settings.
    @discardableResult
    func requestAccess() async -> Bool {
        guard Defaults[.notificationContactsEnabled] else { return false }

        let granted: Bool
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = (try? await store.requestAccess(for: .contacts)) ?? false
        default:
            granted = false
        }
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        return granted
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        if !Defaults[.notificationContactsEnabled] { imageCache.removeAll() }
    }

    func photo(forSenderNamed name: String) -> NSImage? {
        guard Defaults[.notificationContactsEnabled], authorizationStatus == .authorized else {
            return nil
        }
        if let cached = imageCache[name] { return cached }

        let keys = [CNContactImageDataKey, CNContactThumbnailImageDataKey] as [CNKeyDescriptor]
        guard let contacts = try? store.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: name),
            keysToFetch: keys
        ), contacts.count == 1,
              let data = contacts[0].thumbnailImageData ?? contacts[0].imageData,
              let image = NSImage(data: data)
        else {
            imageCache[name] = .some(nil)
            return nil
        }

        imageCache[name] = image
        return image
    }

    /// Returns only an unambiguous, already-international phone number.
    func phoneNumber(forContactNamed name: String) -> String? {
        guard Defaults[.notificationContactsEnabled], authorizationStatus == .authorized else {
            return nil
        }

        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        guard let contacts = try? store.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: name),
            keysToFetch: keys
        ), contacts.count == 1 else { return nil }

        let numbers = contacts[0].phoneNumbers
        let preferred = numbers.first {
            $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone
        } ?? numbers.first

        guard let raw = preferred?.value.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines),
              raw.hasPrefix("+")
        else { return nil }

        let digits = raw.filter(\.isNumber)
        return digits.isEmpty ? nil : digits
    }
}
