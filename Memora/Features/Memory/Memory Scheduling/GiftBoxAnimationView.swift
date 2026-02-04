//
//  GiftBoxAnimationView.swift
//  Memora
//
//  Created by user@3 on 03/02/26.
//


// GiftBoxAnimationView.swift
import SwiftUI
import Combine

struct GiftBoxAnimationView: View {
    @State private var isAnimating = false
    @State private var boxLidAngle: Double = 0
    @State private var boxScale: CGFloat = 1.0
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showContents = false
    @State private var glowRadius: CGFloat = 0
    
    let onOpenComplete: () -> Void
    let memoryTitle: String
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#FFD700").opacity(0.3),
                            Color(hex: "#FFD700").opacity(0.1),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1 : 0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            // Gift Box
            ZStack {
                // Box bottom
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#D4AF37"),
                                Color(hex: "#FFD700"),
                                Color(hex: "#D4AF37")
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 120)
                    .shadow(color: Color(hex: "#FFD700").opacity(0.5), radius: glowRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#B8860B"), lineWidth: 2)
                    )
                
                // Box lid (rotates)
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#FFD700"),
                                Color(hex: "#FFF8DC"),
                                Color(hex: "#FFD700")
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 200, height: 40)
                    .offset(y: -70)
                    .rotation3DEffect(
                        .degrees(boxLidAngle),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.5
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#B8860B"), lineWidth: 2)
                    )
                
                // Ribbon
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: "#8B0000"))
                        .frame(width: 8, height: 120)
                    
                    Rectangle()
                        .fill(Color(hex: "#8B0000"))
                        .frame(width: 180, height: 8)
                    
                    Rectangle()
                        .fill(Color(hex: "#8B0000"))
                        .frame(width: 8, height: 120)
                }
                
                // Ribbon bow
                ZStack {
                    // Left bow loop
                    Ellipse()
                        .fill(Color(hex: "#8B0000"))
                        .frame(width: 40, height: 30)
                        .offset(x: -20, y: -50)
                    
                    // Right bow loop
                    Ellipse()
                        .fill(Color(hex: "#8B0000"))
                        .frame(width: 40, height: 30)
                        .offset(x: 20, y: -50)
                    
                    // Center knot
                    Circle()
                        .fill(Color(hex: "#8B0000"))
                        .frame(width: 24, height: 24)
                        .offset(y: -50)
                        .overlay(
                            Circle()
                                .fill(Color(hex: "#FFD700"))
                                .frame(width: 12, height: 12)
                                .offset(y: -50)
                        )
                }
                
                // Glowing particles
                ForEach(confettiParticles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }
            }
            .scaleEffect(boxScale)
            
            // Memory content (appears after opening)
            if showContents {
                VStack(spacing: 20) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color(hex: "#5AC8FA").opacity(0.8))
                                .frame(width: 100, height: 100)
                        )
                    
                    Text(memoryTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Your memory is now unlocked!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#F2F2F7"))
                        .opacity(0.9)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#5AC8FA").opacity(0.9),
                                    Color(hex: "#007AFF").opacity(0.9)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(hex: "#007AFF").opacity(0.5), radius: 20)
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
        .onAppear {
            startOpeningAnimation()
        }
    }
    
    private func startOpeningAnimation() {
        // Initial pulse
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            isAnimating = true
            boxScale = 1.1
        }
        
        // Sequence of animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Shake animation
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 5)) {
                boxScale = 1.15
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Open lid
                withAnimation(.easeOut(duration: 0.8)) {
                    boxLidAngle = -120
                }
                
                // Glow effect
                withAnimation(.easeOut(duration: 0.5)) {
                    glowRadius = 30
                }
                
                // Generate confetti
                generateConfetti()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Show contents
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContents = true
                    }
                    
                    // Complete callback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onOpenComplete()
                    }
                }
            }
        }
    }
    
    private func generateConfetti() {
        var particles: [ConfettiParticle] = []
        let colors: [Color] = [
            Color(hex: "#FFD700"),
            Color(hex: "#FF6B6B"),
            Color(hex: "#4ECDC4"),
            Color(hex: "#FFE66D"),
            Color(hex: "#5AC8FA")
        ]
        
        for i in 0..<50 {
            let particle = ConfettiParticle(
                id: i,
                x: Double.random(in: -100...100),
                y: Double.random(in: -150...50),
                size: Double.random(in: 4...12),
                color: colors.randomElement()!,
                opacity: 1.0
            )
            particles.append(particle)
            
            // Animate each particle falling
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.01) {
                withAnimation(.easeOut(duration: 1.5)) {
                    if let index = confettiParticles.firstIndex(where: { $0.id == particle.id }) {
                        confettiParticles[index].y += 300
                        confettiParticles[index].opacity = 0
                    }
                }
            }
        }
        
        confettiParticles = particles
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    var x: Double
    var y: Double
    var size: Double
    let color: Color
    var opacity: Double
}