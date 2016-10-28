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

class ActionCableClientTest: QuickSpec {
    
    override func spec() {
        describe("Connection") {
            
            context("with a successful connection") {
                var client: ActionCableClient?
                var connected = false
                
                beforeSuite {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    client!.onConnected = { connected = true }
                    client!.connect()
                }
                
                afterSuite {
                    client!.disconnect()
                    client = nil
                }
                
                it("makes the connect property become true") {
                    expect(client!.isConnected).toEventually(beTrue())
                }
                
                it("fired a callback") {
                    expect(connected).toEventually(beTrue())
                }
            }
            
            context("with a successful disconnection") {
                var client: ActionCableClient?
                var connected = true
                var disconnectError : ConnectionError? = ConnectionError.none
                
                beforeSuite {
                    client = ActionCableClient(url: TestConfiguration.GoodURL)
                    
                    client!.onConnected = {
                        client!.disconnect()
                    }
                    
                    client!.onDisconnected = {(error: ConnectionError?) in
                        disconnectError = error
                        connected = false
                    }
                    
                    client!.connect()
                }
                
                afterSuite {
                    client = nil
                }
                
                it ("makes the connect property become false") {
                    expect(client!.isConnected).toEventually(beFalse())
                }
                
                it ("fires a callback") {
                    expect(connected).toEventually(beFalse())
                }
                
                it ("has no error") {
                    expect(disconnectError).toEventually(beNil())
                }
            }
            
            context("with a bad url") {
                var client: ActionCableClient? = ActionCableClient(url: TestConfiguration.BadURL)
                var connectedInConnectionBlock = false
                var connectedInDisconnectionBlock = true
                var disconnectError : ConnectionError? = ConnectionError.none
                
                client?.onConnected = {
                    connectedInConnectionBlock = true
                }
                
                client?.onDisconnected = {(error: ConnectionError?) in
                    connectedInDisconnectionBlock = false
                    disconnectError = error
                }
                
                beforeSuite {
                    client?.connect()
                }
                
                afterSuite {
                    client = nil
                }
                
                it ("does not show itself to be connected") {
                    expect(client!.isConnected).toEventually(beFalse())
                    expect(connectedInConnectionBlock).toEventually(beFalse())
                }
                
                it ("fires a callback") {
                    expect(connectedInDisconnectionBlock).toEventually(beFalse())
                }
                
                it ("has an error in the callback") {
//                    expect(disconnectError).toEventually(<#T##matcher: U##U#>)
////                    expect(disconnectError).toEventually(beTruthy())
                }
            }
        }
    }
}

