//
//  Persistence.swift
//  Affirmate
//
//  Created by Bri on 10/22/22.
//

import CoreData
import Foundation

class Persistence: ObservableObject {
    
    let container = NSPersistentCloudKitContainer(name: "iCloud.Affirmate")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error)")
            }
        }
    }
}
