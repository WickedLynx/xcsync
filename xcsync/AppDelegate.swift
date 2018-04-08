//
//  AppDelegate.swift
//  xcsync
//
//  Created by Harshad on 08/04/2018.
//  Copyright © 2018 Harshad Dange. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow?
    @IBOutlet weak var imageView: NSImageView?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let imageURL = Bundle.main.url(forResource: "nyancat", withExtension: "gif") {
            imageView?.canDrawSubviewsIntoLayer = true
            imageView?.image = NSImage(byReferencing: imageURL)
        }
        XCSync.run()
    }
}

