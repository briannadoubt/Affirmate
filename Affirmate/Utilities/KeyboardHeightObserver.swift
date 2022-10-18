//
//  KeyboardHeightObserver.swift
//  Chat
//
//  Created by Bri on 1/15/22.
//

import Combine
import SwiftUI

#if os(iOS)
public class KeyboardHeightObserver: ObservableObject {
    
    @Published public var height: CGFloat = 0

    fileprivate var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue }
                .map { $0.cgRectValue.height },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .eraseToAnyPublisher()
    }
    
    fileprivate var heightSink: AnyCancellable?
    
    public func setSink() {
        heightSink = keyboardHeightPublisher.sink{ newHeight in
            Task {
                await self.set(newHeight: newHeight)
            }
        }
    }
    
    @MainActor fileprivate func set(newHeight: CGFloat) {
        withAnimation(.spring()) {
            self.height = height
        }
    }
}
#endif
