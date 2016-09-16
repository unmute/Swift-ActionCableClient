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
import UIKit
import SnapKit


class ChatView : UIView {
    
    var tableView: UITableView
    var textField: UITextField
    var bottomLayoutConstraint: Constraint? = nil
    
    required override init(frame: CGRect) {
        self.tableView = UITableView()
        self.textField = UITextField()
        
        super.init(frame: frame)
        
        self.tableView.frame = CGRectZero
        self.tableView.contentInset = UIEdgeInsetsMake(0, -5, 0, 0);
        self.addSubview(self.tableView)
        
        self.textField.frame = CGRectZero
        self.textField.borderStyle = UITextBorderStyle.Bezel
        self.textField.returnKeyType = UIReturnKeyType.Send
        self.textField.placeholder = "Say something..."
        self.addSubview(self.textField)
        
        self.backgroundColor = UIColor.whiteColor()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ChatView.keyboardWillShowNotification(_:)), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ChatView.keyboardWillHideNotification(_:)), name: UIKeyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        
        tableView.snp_remakeConstraints { (make) -> Void in
            make.top.left.right.equalTo(self)
            make.bottom.equalTo(textField.snp_top)
        }
        
        textField.snp_remakeConstraints { (make) -> Void in
            make.left.right.equalTo(self)
            make.top.equalTo(tableView.snp_bottom)
            make.height.equalTo(50.0)
            self.bottomLayoutConstraint = make.bottom.equalTo(self).constraint
        }
    }
    
    func requiresConstraintBasedLayout() -> Bool {
        return true
    }
}


//MARK: Notifications
extension ChatView {
    func keyboardWillHideNotification(notification: NSNotification) {
        let userInfo = notification.userInfo!
        let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let rawAnimationCurve = (notification.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).unsignedIntValue << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(rawAnimationCurve))
        
        UIView.animateWithDuration(animationDuration, delay: 0.0, options: [.BeginFromCurrentState, animationCurve], animations: {
            self.bottomLayoutConstraint?.updateOffset(0)
            self.updateConstraintsIfNeeded()
            }, completion: nil)
    }
    
    func keyboardWillShowNotification(notification: NSNotification) {
        let userInfo = notification.userInfo!
        let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let keyboardEndFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        let convertedKeyboardEndFrame = self.convertRect(keyboardEndFrame, fromView: self.window)
        let rawAnimationCurve = (notification.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! NSNumber).unsignedIntValue << 16
        let animationCurve = UIViewAnimationOptions(rawValue: UInt(rawAnimationCurve))
        UIView.animateWithDuration(animationDuration, delay: 0.0, options: [.BeginFromCurrentState, animationCurve], animations: {
            self.bottomLayoutConstraint?.updateOffset(-convertedKeyboardEndFrame.height)
            self.updateConstraintsIfNeeded()
        }, completion: nil)
    }
}

