//
//  ThrowingTaskButton.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct ThrowingTaskButton<Label: View>: View {
    var action: () async throws -> ()
    var onThrow: ((_ error: Error) -> ())?
    var label: () -> Label
    init(
        action: @escaping () async throws -> (),
        onThrow: ((_ error: Error) -> ())?,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.onThrow = onThrow
        self.label = label
    }
    func task() {
        Task {
            do {
                try await action()
            } catch {
                onThrow?(error)
            }
        }
    }
    var body: some View {
        Button(action: task, label: label)
    }
}

struct ThrowingTaskButton_Previews: PreviewProvider {
    static var previews: some View {
        ThrowingTaskButton {
            print("Action")
        } onThrow: { error in
            print(error)
        } label: {
            Text("Demo")
        }
    }
}
