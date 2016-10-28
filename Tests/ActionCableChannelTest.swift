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

import Quick
import Nimble
import ActionCableClient

class ActionCableChannelTest : QuickSpec {
    
    override func spec() {
      
        var client: ActionCableClient?
        var channel: Channel?
        
        afterEach {
            client = nil
            channel = nil
        }
        
        describe("Creation") {
            beforeEach {
                client = ActionCableClient(url: TestConfiguration.GoodURL)
            }
            
            it ("Creates a Channel") {
                channel = client?.create(TestConfiguration.EchoChannel)
                expect(channel).toNot(beNil())
            }
        }
        
        describe("Subscriptions") {
            var subscribedCallback = false
            
            context("Auto Subscribing") {
                beforeEach {
                    waitUntil(timeout: 2.0, action: { (done) -> Void in
                        client = ActionCableClient(url: TestConfiguration.GoodURL)
                        client?.connect()
                        channel = client!.create(TestConfiguration.EchoChannel)
                        
                        channel!.onSubscribed = {
                            subscribedCallback = true
                            done()
                        }
                    })
                }
                
                afterEach {
                    client?.disconnect()
                    client = nil
                    channel = nil
                }
                
                it ("gets a subscribed callback") {
                    expect(subscribedCallback).to(beTrue())
                }
                
                it ("has a subscribed property that is true") {
                    expect(channel!.isSubscribed).to(beTrue())
                }
                
                it ("can send an action on a channel") {
                    let error = channel!.action(TestConfiguration.EchoChannelAction, with: ["hello":"world"])
                    expect(error).to(beNil())
                }
            }
            
            context("Manual Subscribing") {
                beforeEach {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    channel = client!.create(TestConfiguration.EchoChannel, identifier: nil, autoSubscribe: false, bufferActions: true)
                    waitUntil(timeout: 1.0, action: { (done) -> Void in
                        client?.connect()
                        client?.onConnected = {
                            done()
                        }
                    })
                }
                
                afterEach {
                    client?.disconnect()
                    client = nil
                    channel = nil
                }
                
                it("is not subscribed") {
                    expect(channel?.isSubscribed).toEventuallyNot(beTrue(), timeout: 3.0, pollInterval: 0.5, description: "not subscribed")
                }
                
                it("is subscribed after subscribing") {
                    channel?.subscribe()
                    expect(channel?.isSubscribed).toEventually(beTrue(), timeout: 3.0, pollInterval: 0.5, description: "be subscribed")
                }
            }
            
            context("Rejecting Subscription") {
                var rejected = false
                
                beforeEach {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    channel = client!.create(TestConfiguration.RejectChannel)
                    waitUntil(timeout: 1.0, action: { (done) -> Void in
                        client?.connect()
                        channel?.onRejected = {
                            rejected = true
                            done()
                        }
                    })
                }
                
                afterEach {
                    client?.disconnect()
                    client = nil
                    channel = nil
                }
                
                it("has a rejected callback") {
                    expect(rejected).to(beTrue())
                }
                
                it("subscribed property is false") {
                    expect(channel?.isSubscribed).to(beFalse())
                }
            }
            
            context("Unsubscribed") {
                var unsubscribed = false
                
                beforeEach {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    channel = client!.create(TestConfiguration.EchoChannel)
                    channel?.onSubscribed = {
                        channel?.unsubscribe()
                    }
                    
                    channel?.onUnsubscribed = {
                        unsubscribed = true
                    }
                    
                    client?.connect()
                }
                
                afterEach {
                    client?.disconnect()
                    client = nil
                    channel = nil
                    unsubscribed = false
                }
                
                it("has an unsubscribed callback") {
                    expect(unsubscribed).toEventually(beTrue(), timeout: 3.0, pollInterval: 0.1, description: "")
                }
                
                it("subscribed property is false") {
                    expect(channel?.isSubscribed).toEventually(beFalse(), timeout: 3.0, pollInterval: 0.1, description: "")
                }
            }
        }
        
        describe("Actions") {
            
            context("Response") {
                var client : ActionCableClient?
                var channel : Channel?
                var receiveResponse : Any?
                var receiveError : Error?
                let params = ["hello":"world"]
                
                var actionReceiveResponse : Any?
                var actionReceiveError: Swift.Error?
                
                beforeEach {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    channel = client!.create(TestConfiguration.EchoChannel, identifier: nil, autoSubscribe: true, bufferActions: false)
                    channel!.onSubscribed = {
                        channel!.action(TestConfiguration.EchoChannelAction, with: params)
                    }
                    
                    waitUntil(timeout: 3.0) { (done) -> Void in
                        channel!.onReceive(TestConfiguration.EchoChannelAction) {(obj: Any?, error: Swift.Error?) in
                            actionReceiveResponse = obj
                            actionReceiveError = error
                        }
                        
                        channel!.onReceive = {(obj: Any?, error: Error?) in
                            receiveResponse = obj
                            receiveError = error
                            
                            done()
                        }
                        
                        client?.connect()
                    }
                }
                
                afterEach {
                    client?.disconnect()
                    client = nil
                    channel = nil
                    receiveResponse = nil
                    receiveError = nil
                    actionReceiveResponse = nil
                    actionReceiveError = nil
                }
                
                it ("gets a response on generic listener") {
                    expect(receiveResponse).toEventuallyNot(beNil(), timeout: 3.0, pollInterval: 0.1, description: "")
                    expect(receiveError).toEventually(beNil(), timeout: 3.0, pollInterval: 0.1, description: "")
                }
                
                it ("gets an expected response") {
                  expect(receiveResponse).notTo(beNil());
                    if let obj = receiveResponse as? Dictionary<String, String> {
                        expect(obj.keys).to(contain(params.keys.first!))
                    } else {
                        expect(receiveResponse).notTo(beNil())
//                        expect(receiveResponse.keys).to(contain(params.keys.first!))
                    }
                }
                
                it ("gets a response on action specific listener") {
                    expect(actionReceiveResponse).toEventuallyNot(beNil(), timeout: 3.0, pollInterval: 0.1, description: "")
                    expect(actionReceiveError).toEventually(beNil(), timeout: 3.0, pollInterval: 0.1, description: "")
                }
            }
            
            context("Buffered") {
                var channel : Channel?
                var receiveResponse : Any?
                var receiveError : Error?
                let params = ["hello":"world"]
                
                beforeEach {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    channel = client!.create(TestConfiguration.EchoChannel)
                    channel!.action(TestConfiguration.EchoChannelAction, with: params)
                    waitUntil(timeout: 3.0, action: { (done) -> Void in
                        client?.connect()
                        channel!.onReceive = {(obj: Any?, error: Error?) in
                            receiveResponse = obj
                            receiveError = error
                            done()
                        }
                    })
                }
                
                afterEach {
                    client?.disconnect()
                    client = nil
                    channel = nil
                    receiveResponse = nil
                    receiveError = nil
                }
                
                it ("gets a response") {
                    expect(receiveResponse).toNot(beNil())
                    expect(receiveError).to(beNil())
                }
            }
            
            context("Unbuffered") {
                var channel : Channel?
                var receiveResponse : Any?
                let params = ["hello":"world"]
                
                beforeEach {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    channel = client!.create(TestConfiguration.EchoChannel, identifier: nil, autoSubscribe: true, bufferActions: false)
                    channel!.action(TestConfiguration.EchoChannelAction, with: params)
                    client?.connect()
                    channel!.onReceive = {(obj: Any?, error: Error?) in
                        receiveResponse = obj
                    }
                }
                
                it ("gets no response") {
                    expect(receiveResponse).toEventually(beNil(), timeout: 5.0, pollInterval: 0.5, description: "no response")
                }
            }
        }
    }
    
}

