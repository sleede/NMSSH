import Foundation
import CryptoKit

@objc public class Ed25519Bridge: NSObject {
    
    @objc public static func createKeyPair() -> [String: Data]? {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation
        let privateKeyData = privateKey.rawRepresentation
        
        return [
            "private": privateKeyData,
            "public": publicKeyData
        ]
    }
    
    @objc public static func createPrivateKey(from data: Data) -> Any? {
        guard data.count == 32 else { return nil }
        do {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        } catch {
            return nil
        }
    }
    
    @objc public static func getPublicKey(from privateKey: Any) -> Data? {
        guard let key = privateKey as? Curve25519.Signing.PrivateKey else { return nil }
        return key.publicKey.rawRepresentation
    }
    
    @objc public static func sign(data: Data, with privateKey: Any) -> Data? {
        guard let key = privateKey as? Curve25519.Signing.PrivateKey else { return nil }
        do {
            let signature = try key.signature(for: data)
            return signature
        } catch {
            return nil
        }
    }
}
