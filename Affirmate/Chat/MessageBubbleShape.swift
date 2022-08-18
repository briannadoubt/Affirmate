//
//  MessageBubbleShape.swift
//  
//
//  Created by Bri on 1/14/22.
//

import SwiftUI

public struct MessageBubbleShape: Shape {
    public func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        if tailPosition.isOnTop ?? false {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + 10))
            path.addRoundedRect(in: CGRect(x: 0, y: 10, width: rect.maxX, height: rect.maxY), cornerSize: CGSize(width: 10, height: 10), style: .circular)
        } else {
            path.move(to: CGPoint.zero)
            path.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.maxX, height: rect.maxY - 10), cornerSize: CGSize(width: 10, height: 10), style: .circular)
        }
        
        switch tailPosition {
        case .leftBottomLeading:
            path.move(to: CGPoint(x: rect.minX + 10.0, y: rect.maxY - 10.0))
            path.addLine(to: CGPoint(x: rect.minX + 10.0, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + 25.0, y: rect.maxY - 10.0))
        case .leftBottomTrailing:
            path.move(to: CGPoint(x: rect.maxX - 25.0, y: rect.maxY - 10.0))
            path.addLine(to: CGPoint(x: rect.maxX - 25.0, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - 10.0, y: rect.maxY - 10.0))
        case .leftTopLeading:
            path.move(to: CGPoint(x: rect.minX + 10.0, y: rect.minY + 10.0))
            path.addLine(to: CGPoint(x: rect.minX + 10.0, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + 25.0, y: rect.minY + 10.0))
        case .leftTopTrailing:
            path.move(to: CGPoint(x: rect.maxX - 25.0, y: rect.minY + 10.0))
            path.addLine(to: CGPoint(x: rect.maxX - 25.0, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - 10.0, y: rect.minY + 10.0))
        case .rightBottomLeading:
            path.move(to: CGPoint(x: rect.minX + 25.0, y: rect.maxY - 10.0))
            path.addLine(to: CGPoint(x: rect.minX + 25.0, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + 10.0, y: rect.maxY - 10.0))
        case .rightBottomTrailing:
            path.move(to: CGPoint(x: rect.maxX - 25.0, y: rect.maxY - 10.0))
            path.addLine(to: CGPoint(x: rect.maxX - 10.0, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - 10.0, y: rect.maxY - 10.0))
        case .rightTopLeading:
            path.move(to: CGPoint(x: rect.minX + 25.0, y: rect.minY + 10.0))
            path.addLine(to: CGPoint(x: rect.minX + 25.0, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + 10.0, y: rect.minY + 10.0))
        case .rightTopTrailing:
            path.move(to: CGPoint(x: rect.maxX - 25.0, y: rect.minY + 10.0))
            path.addLine(to: CGPoint(x: rect.maxX - 10.0, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - 10.0, y: rect.minY + 10.0))
        case .none:
            break
        }
        
        path.closeSubpath()
        
        return path
    }
    
    public var tailPosition: MessageBubbleTailPosition = .sender
    
    init(_ tailPosition: MessageBubbleTailPosition = .sender) {
        self.tailPosition = tailPosition
    }
}
