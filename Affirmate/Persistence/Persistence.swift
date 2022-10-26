//
//  Persistence.swift
//  Affirmate
//
//  Created by Bri on 10/22/22.
//

import CoreData
import Foundation

class Persistence: ObservableObject {
    
    var container = NSPersistentCloudKitContainer(name: "Affirmate")
    
    init() {
        load()
    }
    
    private func load() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error)")
            }
        }
    }
    
    func deleteEverything() throws {
        let storeCoordinator = container.persistentStoreCoordinator
        for store in storeCoordinator.persistentStores {
            guard let url = store.url else {
                continue
            }
            try storeCoordinator.destroyPersistentStore(at: url, ofType: store.type, options: nil)
        }
        container = NSPersistentCloudKitContainer(name: "Affirmate")
        load()
    }
}
