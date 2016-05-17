//
//  TransportHelper.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 16/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation

final class TransportHelper {
    
    enum CommandType: UInt8 {
        case Ping = 0x81
        case KeepAlive = 0x82
        case Message = 0x83
        case Error = 0xbf
    }
    
    enum ChunkType {
        case Ping
        case KeepAlive
        case Message
        case Error
        case Continuation
        case Unknown
    }
    
    static func getChunkType(data: NSData) -> ChunkType {
        let reader = DataReader(data: data)
        guard let byte = reader.readNextUInt8() else {
            return .Unknown
        }
        
        if byte & 0x80 == 0 {
            return .Continuation
        }
        
        switch byte {
        case CommandType.Ping.rawValue: return .Ping
        case CommandType.KeepAlive.rawValue: return .KeepAlive
        case CommandType.Message.rawValue: return .Message
        case CommandType.Error.rawValue: return .Error
        default: return .Unknown
        }
    }
    
    static func split(data: NSData, command: CommandType, chuncksize: Int) -> [NSData]? {
        guard chuncksize >= 8 && data.length > 0 && data.length <= Int(UInt16.max) else { return nil }
        var chunks: [NSData] = []
        var remainingLength = data.length
        var firstChunk = true
        var sequence: UInt8 = 0
        var offset = 0
        
        while remainingLength > 0 {
            var length = 0
            let writer = DataWriter()
            
            if firstChunk {
                writer.writeNextUInt8(command.rawValue)
                writer.writeNextBigEndianUInt16(UInt16(remainingLength))
                length = min(chuncksize - 3, remainingLength)
            }
            else {
                writer.writeNextUInt8(sequence)
                length = min(chuncksize - 1, remainingLength)
            }
            writer.writeNextData(data.subdataWithRange(NSMakeRange(offset, length)))
            remainingLength -= length
            offset += length
            chunks.append(writer.data)
            if !firstChunk {
                sequence += 1
            }
            firstChunk = false
        }
        return chunks
    }
    
    static func join(chunks: [NSData], command: CommandType) -> NSData? {
        let writer = DataWriter()
        var sequence: UInt8 = 0
        var length = -1
        var firstChunk = true
        
        for chunk in chunks {
            let reader = DataReader(data: chunk)

            if firstChunk {
                guard
                    let readCommand = reader.readNextUInt8(),
                    let readLength = reader.readNextBigEndianUInt16()
                where
                    readCommand == command.rawValue
                else
                    { return nil }
                
                length = Int(readLength)
                writer.writeNextData(chunk.subdataWithRange(NSMakeRange(3, chunk.length - 3)))
                length -= chunk.length - 3
                firstChunk = false
            }
            else {
                guard
                    let readSequence = reader.readNextUInt8()
                where
                    readSequence == sequence
                else
                    { return nil }
                
                writer.writeNextData(chunk.subdataWithRange(NSMakeRange(1, chunk.length - 1)))
                length -= chunk.length - 1
                sequence += 1
            }
        }
        if length != 0 {
            return nil
        }
        return writer.data
    }
    
}