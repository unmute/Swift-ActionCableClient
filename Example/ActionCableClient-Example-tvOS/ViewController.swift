//
//  ViewController.swift
//  ActionCableClient-Example-tvOS
//
//  Created by Daniel Rhodes on 8/27/16.
//  Copyright © 2016 Daniel Rhodes. All rights reserved.
//

import UIKit
import ActionCableClient

class ViewController: UIViewController {
  
  let client = ActionCableClient(URL: URL(string:"ws://actioncable-echo.herokuapp.com/cable")!)
  var channel: Channel?

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }


}

