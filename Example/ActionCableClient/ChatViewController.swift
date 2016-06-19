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

import UIKit
import ActionCableClient
import SnapKit
import SwiftyJSON


class ChatViewController: UIViewController {
    static var MessageCellIdentifier = "MessageCell"
    static var ChannelIdentifier = "ChatChannel"
    static var ChannelAction = "talk"
    
    let client = ActionCableClient(URL: NSURL(string:"ws://localhost:3000/cable")!)
    var channel: Channel?
    
    var history: Array<ChatMessage> = Array()
    var name: String?
    
    var chatView: ChatView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Chat"
        
        chatView = ChatView(frame: view.bounds)
        view.addSubview(chatView!)
        
        chatView?.snp_remakeConstraints(closure: { (make) -> Void in
            make.top.bottom.left.right.equalTo(self.view)
        })
        
        chatView?.tableView.delegate = self
        chatView?.tableView.dataSource = self
        chatView?.tableView.separatorInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        chatView?.tableView.allowsSelection = false
        chatView?.tableView.registerClass(ChatCell.self, forCellReuseIdentifier: ChatViewController.MessageCellIdentifier)
        
        chatView?.textField.delegate = self
        
        setupClient()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        let alert = UIAlertController(title: "Chat", message: "What's Your Name?", preferredStyle: UIAlertControllerStyle.Alert)
        
        var nameTextField: UITextField?
        alert.addTextFieldWithConfigurationHandler({(textField: UITextField!) in
            textField.placeholder = "Name"
            //🙏 Forgive me father, for I have sinned. 🙏
            nameTextField = textField
        })
        
        alert.addAction(UIAlertAction(title: "Start", style: UIAlertActionStyle.Default) {(action: UIAlertAction) in
            self.name = nameTextField?.text
            self.chatView?.textField.becomeFirstResponder()
        })
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

// MARK: ActionCableClient
extension ChatViewController {
    
    func setupClient() -> Void {
      
          self.client.willConnect = {
              print("Will Connect")
          }
          
          self.client.onConnected = {
              print("Connected to \(self.client.URL)")
          }
          
          self.client.onDisconnected = {(error: ErrorType?) in
              print("Disconected with error: \(error)")
          }
          
          self.client.willReconnect = {
              print("Reconnecting to \(self.client.URL)")
              return true
          }
          
          self.channel = client.create(ChatViewController.ChannelIdentifier)
          self.channel?.onSubscribed = {
              print("Subscribed to \(ChatViewController.ChannelIdentifier)")
          }
        
          self.channel?.onReceive = {(data:AnyObject?, error: ErrorType?) in
            if let _ = error {
                print(error)
                return
            }
            
            let JSONObject = JSON(data!)
            let msg = ChatMessage(name: JSONObject["name"].string!, message: JSONObject["message"].string!)
            self.history.append(msg)
            self.chatView?.tableView.reloadData()
            
            
            // Scroll to our new message!
            if (msg.name == self.name) {
                self.chatView?.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: self.history.count - 1, inSection: 0), atScrollPosition: UITableViewScrollPosition.Bottom, animated: false)
            }
        }
        
        self.client.connect()
    }
    
    func sendMessage(message: String) {
        let prettyMessage = message.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        if (!prettyMessage.isEmpty) {
            print("Sending Message: \(ChatViewController.ChannelIdentifier)#\(ChatViewController.ChannelAction)")
            self.channel?.action(ChatViewController.ChannelAction, params: ["name": self.name!, "message": prettyMessage])
        }
    }
}

//MARK: UITextFieldDelegate
extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.sendMessage(textField.text!)
        textField.text = ""
        return true
    }
}

//MARK: UITableViewDelegate
extension ChatViewController: UITableViewDelegate {
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let message = history[indexPath.row]
        let attrString = message.attributedString()
        let width = self.chatView?.tableView.bounds.size.width;
        let rect = attrString.boundingRectWithSize(CGSize(width: width! - (ChatCell.Inset * 2.0), height: CGFloat.max),
            options: [.UsesLineFragmentOrigin, .UsesFontLeading], context:nil)
        return rect.size.height + (ChatCell.Inset * 2.0)
    }
}

//MARK: UITableViewDataSource
extension ChatViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ChatViewController.MessageCellIdentifier, forIndexPath: indexPath) as! ChatCell
        let msg = history[indexPath.row]
        cell.message = msg
        return cell
    }
}

//MARK: ChatMessage
struct ChatMessage {
    var name: String
    var message: String
    
    func attributedString() -> NSAttributedString {
        let messageString: String = "\(self.name) \(self.message)"
        let nameRange = NSRange(location: 0, length: self.name.characters.count)
        let nonNameRange = NSRange(location: nameRange.length, length: messageString.characters.count - nameRange.length)
        
        let string: NSMutableAttributedString = NSMutableAttributedString(string: messageString)
        string.addAttribute(NSFontAttributeName,
            value: UIFont.boldSystemFontOfSize(18.0),
            range: nameRange)
        string.addAttribute(NSFontAttributeName, value: UIFont.systemFontOfSize(18.0), range: nonNameRange)
        return string
    }
}
