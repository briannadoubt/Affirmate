//
//  TaskButton.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct TaskButton<Label: View>: View {
    var action: () async -> ()
    var label: () -> Label
    init(
        action: @escaping () async -> (),
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.label = label
    }
    func task() {
        Task {
            await action()
        }
    }
    var body: some View {
        Button(action: task, label: label)
    }
}

struct TaskButton_Previews: PreviewProvider {
    static var previews: some View {
        TaskButton {
            print("Action fired")
        } label: {
            Text("Task Button")
        }
    }
}
