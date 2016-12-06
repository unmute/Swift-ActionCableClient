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

public typealias ChannelIdentifier = ActionPayload
public typealias OnReceiveClosure = ((Any?, Swift.Error?) -> (Void))

/// A particular channel on the server.
open class Channel: Hashable, Equatable {
    
    /// Name of the channel
    open var name : String
    
    /// Identifier
    open var identifier: Dictionary<String, Any>?
    
    /// Auto-Subscribe to channel on initialization and re-connect?
    open var autoSubscribe : Bool
    
    /// Buffer actions
    /// If not subscribed, buffer actions and flush until after a subscribe
    open var shouldBufferActions : Bool
    
    /// Subscribed
    open var isSubscribed : Bool {
        return client.subscribed(name)
    }
    
    /// A block called when a message has been received on this channel.
    ///
    /// ```swift
    /// channel.onReceive = { (JSON : AnyObject?, error: Error?) in
    ///   print("Received:", JSON, "Error:", error)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///     - object: Depends on what is sent. Usually a Dictionary.
    ///     - error: An error when decoding of the message failed.
    ///
    open var onReceive: ((Any?, Swift.Error?) -> Void)?
  
    /// A block called when the channel has been successfully subscribed.
    ///
    /// Note: This block will be called if the client disconnects and then
    /// reconnects again.
    ///
    /// ```swift
    /// channel.onSubscribed = {
    ///   print("Yay!")
    /// }
    /// ```
    open var onSubscribed: (() -> Void)?
    
    /// A block called when the channel was unsubscribed.
    ///
    /// Note: This block is also called if the server disconnects.
    open var onUnsubscribed: (() -> Void)?
    
    /// A block called when a subscription attempt was rejected
    /// by the server.
    open var onRejected: (() -> Void)?

    internal init(name: String, identifier: ChannelIdentifier?, client: ActionCableClient, autoSubscribe: Bool=true, shouldBufferActions: Bool=true) {
        self.name = name
        self.client = client
        self.autoSubscribe = autoSubscribe
        self.shouldBufferActions = shouldBufferActions
        self.identifier = identifier
    }
    
    open func onReceive(_ action:String, handler: @escaping (OnReceiveClosure)) -> Void {
        onReceiveActionHooks[action] = handler
    }
    
    /// Subscript for `action:`.
    ///
    /// Send an action to the server.
    ///
    /// Note: ActionCable does not give any confirmation or response that an
    /// action was succcessfully executed or received.
    ///
    /// ```swift
    /// channel['speak'](["message": "Hello, World!"])
    /// ```
    ///
    /// - Parameters:
    ///     - action: The name of the action (e.g. speak)
    ///
    open subscript(name: String) -> (Dictionary<String, Any>?) -> Void {
        
        func executeParams(_ params : Dictionary<String, Any>? = [:])  {
            action(name, with: params)
        }
        
        return executeParams
    }
  
    /// Send an action.
    ///
    /// Note: ActionCable does not give any confirmation or response that an
    /// action was succcessfully executed.
    ///
    /// ```swift
    /// channel.action("speak", with: ["message": "Hello, World!"])
    /// ```
    ///
    /// - Parameters:
    ///     - action: The name of the action (e.g. speak)
    ///     - with: An optional `Dictionary` of JSON encodable values.
    ///
    open func action(_ name: String, with params: [String: Any]? = [:]) {
        action(name, with: params, completion: nil)
    }
  
    /// Send an action.
    ///
    /// Note: ActionCable does not give any confirmation or response that an
    /// action was succcessfully executed.
    ///
    /// ```swift
    /// channel.action("speak", with: ["message": "Hello, World!"]) { error in
    ///   if let error = error {
    ///     // oh no!
    ///   }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///     - name:   The name of the action (e.g. speak)
    ///     - with: An optional `Dictionary` of JSON encodable values.
    ///     - completion: A block called when the transmission was successful or with an error if there were any errors encountered while attempting to transmit. Block is called on the main thread.
    ///
    @discardableResult
    open func action(_ name: String, with params: [String: Any]? = [:], completion: ((Error?) -> ())?) {
        client.action(name, on: self, with: params) { (error) in
            do {
              if let error = error { throw error }

            // Consume the error and return false if the error is a not subscribed
            // error and we are buffering the actions.
            } catch TransmitError.notSubscribed where self.shouldBufferActions {
                ActionCableSerialQueue.async(execute: {
                    self.actionBuffer.append(Action(name: name, params: params))
                })
                
                if let completion = completion {
                    DispatchQueue.main.async {
                        completion(TransmitError.notSubscribed)
                    }
                }
            } catch {
                if let completion = completion {
                    DispatchQueue.main.async {
                        completion(error)
                    }
                }
            }
        }
    }
    
    /// Subscribe to the channel on the server.
    ///
    /// This should be unnecessary if autoSubscribe is `true`.
    ///
    /// ```swift
    /// channel.subscribe()
    /// ```
    open func subscribe() {
        client.subscribe(self)
    }
    
    /// Unsubscribe from the channel on the server.
    ///
    /// Upon unsubscribing, ActionCableClient will stop retaining this object.
    ///
    /// ```swift
    /// channel.unsubscribe()
    /// ```
    open func unsubscribe() {
        client.unsubscribe(self)
    }
    
    internal var onReceiveActionHooks: Dictionary<String, OnReceiveClosure> = Dictionary()
    internal unowned var client: ActionCableClient
    internal var actionBuffer: Array<Action> = Array()
    open let hashValue: Int = Int(arc4random_uniform(UInt32(Int32.max)))
}

public func ==(lhs: Channel, rhs: Channel) -> Bool {
  return (lhs.hashValue == rhs.hashValue) && (lhs.name == rhs.name)
}

extension Channel {
    internal func onMessage(_ message: Message) {
        switch message.messageType {
            case .message:
                if let callback = self.onReceive {
                    DispatchQueue.main.async(execute: { callback(message.data, message.error) })
                }
                
                if let actionName = message.actionName, let callback = self.onReceiveActionHooks[actionName] {
                    DispatchQueue.main.async(execute: { callback(message.data, message.error) })
                }
            case .confirmSubscription:
                if let callback = self.onSubscribed {
                    DispatchQueue.main.async(execute: callback)
                }
                
                self.flushBuffer()
            case .rejectSubscription:
                if let callback = self.onRejected {
                    DispatchQueue.main.async(execute: callback)
                }
            case .hibernateSubscription:
              fallthrough
            case .cancelSubscription:
                if let callback = self.onUnsubscribed {
                    DispatchQueue.main.async(execute: callback)
                }
            default: break
        }
    }
    
    internal func flushBuffer() {
        ActionCableSerialQueue.sync(execute: {() -> Void in
            // Bail out if the parent is gone for whatever reason
            while let action = self.actionBuffer.popLast() {
                self.action(action.name, with: action.params)
            }
        })
    }
}

extension Channel {
    func copyWithZone(_ zone: NSZone?) -> AnyObject! {
        assert(false, "This class doesn't implement NSCopying. ")
        return nil
    }
    
    func copy() -> AnyObject! {
        assert(false, "This class doesn't implement NSCopying")
        return nil
    }
}

extension Channel: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "ActionCable.Channel<\(hashValue)>(name: \"\(self.name)\" subscribed: \(self.isSubscribed))"
    }
}

extension Channel: CustomPlaygroundQuickLookable {
    /// A custom playground quick look for this instance.
    ///
    /// If this type has value semantics, the `PlaygroundQuickLook` instance
    /// should be unaffected by subsequent mutations.
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
              return PlaygroundQuickLook.text(self.name)
    }
}
