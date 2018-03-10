//
//  Blob.swift
//  Paseto
//
//  Created by Aidan Woods on 05/03/2018.
//

import Foundation

public struct Blob<P: VersionedPayload, V> where V == P.VersionType {
    public let header: Header = Blob.header
    let payload: P
    public let footer: Data

    init (payload: P, footer: Data = Data()) {
        self.payload = payload
        self.footer  = footer
    }

    public init? (_ string: String) {
        guard let (
            header: header,
            encodedPayload: encodedPayload,
            encodedFooter: encodedFooter
        ) = Blob.deconstruct(string)
        else { return nil }

        guard header == Blob.header,
              let payload = P(encoded: encodedPayload),
              let footer = Data(base64UrlNoPad: encodedFooter)
        else { return nil }

        self.init(payload: payload, footer: footer)
    }

    internal static func deconstruct(
        _ string: String
    ) -> (header: Header, encodedPayload: String, encodedFooter: String)? {
        let parts = Header.split(string)

        guard [3, 4].contains(parts.count) else { return nil }

        guard let header = Header(version: parts[0], purpose: parts[1])
        else { return nil }

        return (
            header: header,
            encodedPayload: parts[2],
            encodedFooter: parts.count > 3 ? parts[3] : ""
        )
    }

    public static func header(_ string: String) -> Header? {
        return deconstruct(string)?.header
    }

    public static var header: Header {
        return Header(
            version: Version(implementation: V.self),
            purpose: Purpose(payload: P.self)
        )
    }
}

public extension Blob {
    public var asString: String {
        let main = header.asString + payload.encode
        guard !footer.isEmpty else { return main }
        return main + "." + footer.base64UrlNoPad
    }

    public var asData: Data { return Data(self.asString.utf8) }
}

public extension Blob where P == Signed<V> {
    func verify(with key: AsymmetricPublicKey<V>) throws -> Token {
        let message = try V.verify(self, with: key)
        return try token(jsonData: message)
    }

    func verify(with key: AsymmetricPublicKey<V>) -> Token? {
        return try? verify(with: key)
    }
}

public extension Blob where P == Encrypted<V> {
    func decrypt(with key: SymmetricKey<V>) throws -> Token {
        let message = try V.decrypt(self, with: key)
        return try token(jsonData: message)
    }

    func decrypt(with key: SymmetricKey<V>) -> Token? {
        return try? decrypt(with: key)
    }
}

extension Blob {
    func token(jsonData: Data) throws -> Token {
        guard let footer = self.footer.utf8String else {
            throw Exception.badEncoding(
                "Could not convert the footer to a UTF-8 string."
            )
        }

        return try Token(
            jsonData: jsonData,
            footer: footer,
            allowedVersions: [header.version]
        )
    }
}

extension Blob {
    enum Exception: Error {
        case badEncoding(String)
    }
}
