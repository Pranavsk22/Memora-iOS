//
//  Extensions.swift
//  Memora
//
//  Created by user@3 on 03/02/26.
//


// Extensions.swift
import UIKit

// MARK: - Date Extensions
extension Date {
    func formattedTimeRemaining(until targetDate: Date) -> String {
        let interval = targetDate.timeIntervalSince(self)
        
        if interval <= 0 {
            return "Ready!"
        }
        
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - UIView Extensions for Animations
extension UIView {
    func pulseAnimation() {
        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.duration = 0.6
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.initialVelocity = 0.5
        pulse.damping = 0.8
        
        layer.add(pulse, forKey: "pulse")
    }
    
    func stopPulseAnimation() {
        layer.removeAnimation(forKey: "pulse")
    }
    
    func glowAnimation(color: UIColor, radius: CGFloat) {
        layer.shadowColor = color.cgColor
        layer.shadowRadius = radius
        layer.shadowOpacity = 0.8
        layer.shadowOffset = .zero
        
        let animation = CABasicAnimation(keyPath: "shadowOpacity")
        animation.fromValue = 0.8
        animation.toValue = 0.4
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "glow")
    }
}