//
//  DisplayManagerApp.swift
//  DisplayManager
//
//  Created by Divyansh Singh on 05/07/25.
//

import SwiftUI

@main
struct DisplayManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
