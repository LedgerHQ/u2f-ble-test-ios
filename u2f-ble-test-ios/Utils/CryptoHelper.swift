//
//  CryptoHelper.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 17/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation
import Security

@objc final class CryptoHelper: NSObject {
    
    static func verifyRegisterSignature(APDU: RegisterAPDU) ->  Bool {
        guard
            let certificate = APDU.certificate,
            let signature = APDU.signature,
            let keyHandle = APDU.keyHandle,
            let publicKey = APDU.publicKey,
            let extractedSignaturePoints = extractPointsFromSignature(signature)
        else {
            return false
        }
        
        // extract certificate publickey
        var trustRef: SecTrustRef? = nil
        let policy = SecPolicyCreateBasicX509()
        guard
            let certificateRef = SecCertificateCreateWithData(nil, certificate)
        where
            SecTrustCreateWithCertificates(certificateRef, policy, &trustRef) == errSecSuccess &&
            trustRef != nil
        else {
            return false
        }
        let key = SecTrustCopyPublicKey(trustRef!)
        let certificatePublicKey = getPublicKeyBitsFromKey(key)

        // check signature
        let crypto = GMEllipticCurveCrypto(forKey: certificatePublicKey)
        let data = NSMutableData()
        data.appendBytes([0x00] as [UInt8], length: 1)
        data.appendData(APDU.applicationParameter)
        data.appendData(APDU.challenge)
        data.appendData(keyHandle)
        data.appendData(publicKey)
        let extractedSignature = NSMutableData()
        extractedSignature.appendData(extractedSignaturePoints.r)
        extractedSignature.appendData(extractedSignaturePoints.s)
        return crypto.hashSHA256AndVerifySignature(extractedSignature, forData: data)
    }
    
    static func verifyAuthenticateSignature(APDU: AuthenticateAPDU) ->  Bool {
        guard
            let publicKey = APDU.registerAPDU.publicKey,
            let userPresenceFlag = APDU.userPresenceFlag,
            let counter = APDU.counter,
            let signature = APDU.signature,
            let extractedSignaturePoints = extractPointsFromSignature(signature)
        else {
            return false
        }
        
        // check signature
        let crypto = GMEllipticCurveCrypto(forKey: publicKey)
        let writer = DataWriter()
        writer.writeNextData(APDU.applicationParameter)
        writer.writeNextUInt8(userPresenceFlag)
        writer.writeNextBigEndianUInt32(counter)
        writer.writeNextData(APDU.challenge)
        let extractedSignature = NSMutableData()
        extractedSignature.appendData(extractedSignaturePoints.r)
        extractedSignature.appendData(extractedSignaturePoints.s)
        return crypto.hashSHA256AndVerifySignature(extractedSignature, forData: writer.data)
    }
    
    static func extractPointsFromSignature(signature: NSData) -> (r: NSData, s: NSData)? {
        let reader = DataReader(data: signature)
        guard
            let _ = reader.readNextUInt8(), // 0x30
            let _ = reader.readNextUInt8(), // length
            let _ = reader.readNextUInt8(), // 0x20
            let rLength = reader.readNextUInt8(),
            let r = reader.readNextMutableDataOfLength(Int(rLength)),
            let _ = reader.readNextUInt8(), // 0x20
            let sLength = reader.readNextUInt8(),
            let s = reader.readNextMutableDataOfLength(Int(sLength))
        else {
            return nil
        }
        let rBytes = UnsafePointer<UInt8>(r.bytes)
        if rBytes[0] == 0x00 {
            r.replaceBytesInRange(NSMakeRange(0, 1), withBytes: nil, length: 0)
        }
        let sBytes = UnsafePointer<UInt8>(s.bytes)
        if sBytes[0] == 0x00 {
            s.replaceBytesInRange(NSMakeRange(0, 1), withBytes: nil, length: 0)
        }
        return (r, s)
    }
    
}