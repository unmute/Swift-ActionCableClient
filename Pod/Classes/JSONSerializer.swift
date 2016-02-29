//
//  Copyright (c) 2016 Daniel Rhodes <rhodes.daniel@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
//  USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import SwiftyJSON

internal class JSONSerializer {
    
    static func serialize(channel : Channel, command: Command, data: Dictionary<String, AnyObject>?) throws -> String {
        
        do {
            var identifierDict : ChannelIdentifier
            if let identifier = channel.identifier {
                identifierDict = identifier
            } else {
                identifierDict = Dictionary()
            }
            
            identifierDict["channel"] = "\(channel.name)"
            
            let JSONData = try NSJSONSerialization.dataWithJSONObject(identifierDict, options: NSJSONWritingOptions(rawValue: 0))
            guard let identifierString = NSString(data: JSONData, encoding: NSUTF8StringEncoding)
                  else { throw SerializationError.JSON }
            
            var commandDict = [
                "command" : command.string,
                "identifier" : identifierString
            ]
            
            if let _ = data {
                let JSONData = try NSJSONSerialization.dataWithJSONObject(data!, options: NSJSONWritingOptions(rawValue: 0))
                guard let dataString = NSString(data: JSONData, encoding: NSUTF8StringEncoding)
                      else { throw SerializationError.JSON }
                
                commandDict["data"] = dataString
            }
            
            let CmdJSONData = try NSJSONSerialization.dataWithJSONObject(commandDict, options: NSJSONWritingOptions(rawValue: 0))
            guard let JSONString = NSString(data: CmdJSONData, encoding: NSUTF8StringEncoding)
                  else { throw SerializationError.JSON }
            
            return JSONString as String
        } catch {
            throw SerializationError.JSON
        }
    }
    
    static func deserialize(string: String) throws -> Message {
        let JSONObj = JSON.parse(string)
        
        var messageType : MessageType?
        
        do {
            if let _ = JSONObj.error {
                throw SerializationError.JSON
            }
            
            guard let idString = JSONObj["identifier"].string
                else { throw SerializationError.ProtocolViolation }
            
            // Is it a ping?
            if idString == MessageType.Ping.string {
                return Message(channelName: nil,
                                actionName: nil,
                               messageType: MessageType.Ping,
                                      data: nil,
                                     error: nil)
            }
            
            let idJSON = JSON.parse(idString)
            
            guard let _ = idJSON.dictionary
                else { throw SerializationError.ProtocolViolation }
            
            guard let channelName = idJSON["channel"].string
                else { throw SerializationError.ProtocolViolation }
            
            if let messageTypeStr = JSONObj["type"].string {
                switch(messageTypeStr) {
                case MessageType.ConfirmSubscription.string:
                    messageType = MessageType.ConfirmSubscription
                case MessageType.RejectSubscription.string:
                    messageType = MessageType.RejectSubscription
                default:
                    throw SerializationError.ProtocolViolation
                }
                
                return Message(channelName: channelName,
                                actionName: nil,
                               messageType: messageType!,
                                      data: nil,
                                     error: nil)
            }
            
            var messageActionName : String?
            var messageValue      : AnyObject?
            var messageError      : ErrorType?
            
            do {
                if !JSONObj["message"].isExists() {
                    throw SerializationError.ProtocolViolation
                }
                
                if let actionName = JSONObj["message"]["action"].string as String! {
                    messageActionName = actionName
                }
                
                messageValue = JSONObj["message"].object
            } catch {
                messageError = error
            }
            
            return Message(channelName: channelName,
                            actionName: messageActionName,
                           messageType: MessageType.Message,
                                  data: messageValue,
                                 error: messageError)
            
        } catch {
            throw error
        }
    }

}