import SwiftUI
import Subsonic

struct Bubble: Identifiable {
    let id = UUID()
    var position: CGPoint
    var speed: CGSize
    var opacity: Double = Double.random(in: 0.3...0.9)
}

struct Spikeball: Identifiable {
    let id = UUID()
    var position: CGPoint
    var speed: CGSize
}

struct TitleScreenView: View {
    @State private var waveOffset: CGFloat = 0.0
    @State private var isGameStarted = false
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var fadeOutOpacity: Double = 1.0
    @State private var menuSize: CGSize = .zero
    @State private var bubbles: [Bubble] = []
    @State private var spikeballs: [Spikeball] = []

    @StateObject private var bgMusic = SubsonicPlayer(sound: "CatOnWindow105.mp3", volume: 0.7, repeatCount: .continuous, playMode: .continue)
    @StateObject private var fxMusic = SubsonicPlayer(sound: "hit1.mp3", volume: 0.7)
    @StateObject private var coinMusic = SubsonicPlayer(sound: "coin.mp3", volume:0.8)
    @StateObject private var waterMusic = SubsonicPlayer(sound: "water.mp3", volume : 0.9)
    
    private let fadeOutDuration = 0.35
    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if showHelp {
                HelpWindow(showHelp: $showHelp, fxMusic: fxMusic)
            } else if showSettings {
                SettingsView(showSettings: $showSettings, bgMusic: bgMusic, fxMusic: fxMusic, coinMusic: coinMusic, waterMusic: waterMusic)
            } else if isGameStarted {
                GameScreenView(
                    onBack: {
                        withAnimation {
                            isGameStarted = false
                            fadeOutOpacity = 1.0
                        }
                        resetForMenu()
                    },
                    bgMusic: bgMusic,
                    fxMusic: fxMusic,
                    coinMusic: coinMusic,
                    waterMusic: waterMusic
                )
            } else {
                mainMenuView
            }
        }
        .onAppear {
            bgMusic.repeatCount = .continuous
            bgMusic.playIfNeeded()
        }
        .onReceive(timer) { _ in
            guard !isGameStarted && !showHelp && !showSettings else { return }
            waveOffset += 0.08
            updateBubbles(in: activeMenuSize())
            updateSpikeballs(in: activeMenuSize())
        }
    }

    private var mainMenuView: some View {
        GeometryReader { geometry in
            mainMenuContent(in: geometry.size, safeAreaInsets: geometry.safeAreaInsets)
        }
    }

    private func mainMenuContent(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            backgroundImage(in: size, safeAreaInsets: safeAreaInsets)
                .opacity(fadeOutOpacity)

            ForEach(bubbles) { bubble in
                Image("bubbl")
                    .resizable()
                    .scaledToFit()
                    .frame(width: bubbleDiameter(in: size), height: bubbleDiameter(in: size))
                    .position(bubble.position)
                    .opacity(bubble.opacity)
                    .opacity(fadeOutOpacity)
            }

            ForEach(spikeballs) { spike in
                Image("spikeball1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: spikeballDiameter(in: size), height: spikeballDiameter(in: size))
                    .position(spike.position)
                    .opacity(0.8)
                    .opacity(fadeOutOpacity)
            }

            VStack(spacing: 0) {
                Spacer(minLength: size.height * 0.12)

                Image("titlefont1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(size.width * 0.78, 330))
                    .offset(y: sin(waveOffset) * 1.5)
                    .opacity(fadeOutOpacity)

                Spacer(minLength: size.height * 0.11)

                VStack(spacing: max(22, size.height * 0.035)) {
                    sineWaveButton(imageName: "start1", width: min(size.width * 0.74, 300), phase: 0) {
                        
                        withAnimation(.easeInOut(duration: fadeOutDuration)) {
                            fadeOutOpacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                            withAnimation {
                                isGameStarted = true
                            }
                            clearActiveEntities()
                        }
                    }
                    .opacity(fadeOutOpacity)

                    sineWaveButton(imageName: "settings2", width: min(size.width * 0.74, 300), phase: 1) {
                        showSettings = true
                        clearActiveEntities()
                        
                    }
                    .opacity(fadeOutOpacity)

                    sineWaveButton(imageName: "help3", width: min(size.width * 0.74, 300), phase: 2) {
                        showHelp = true
                        clearActiveEntities()
                        
                    }
                    .opacity(fadeOutOpacity)
                }

                Spacer(minLength: size.height * 0.12)
            }
            .padding(.horizontal, 24)
            .frame(width: size.width, height: size.height)

            Color.black.opacity(1 - fadeOutOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            updateMenuSize(size)
            if spikeballs.isEmpty {
                spawnInitialSpikeballs(in: size)
            }
        }
        .onChange(of: size) { _, newSize in
            updateMenuSize(newSize)
        }
    }

    private func sineWaveButton(imageName: String, width: CGFloat, phase: Double, action: @escaping () -> Void) -> some View {
        Button(action: {
            waterMusic.play()
            action()
        }) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .offset(y: CGFloat(sin(waveOffset + phase) * 3))
        }
        .buttonStyle(.plain)
    }

    private func backgroundImage(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let width = size.width + safeAreaInsets.leading + safeAreaInsets.trailing + 80
        let height = size.height + safeAreaInsets.top + safeAreaInsets.bottom + 80

        return Image("sea")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .position(x: size.width / 2, y: size.height / 2)
            .clipped()
            .ignoresSafeArea()
    }

    private func updateBubbles(in size: CGSize) {
        var updated: [Bubble] = []
        let padding = bubbleDiameter(in: size) * 2

        for var bubble in bubbles {
            bubble.position.x += bubble.speed.width
            bubble.position.y += bubble.speed.height

            if isOffscreen(bubble.position, in: size, padding: padding) {
                continue
            }

            let collided = spikeballs.contains {
                hypot($0.position.x - bubble.position.x, $0.position.y - bubble.position.y) < bubbleDiameter(in: size)
            }

            if !collided {
                updated.append(bubble)
            }
        }

        bubbles = updated

        if bubbles.count < 6 && Int.random(in: 0..<35) == 0 {
            bubbles.append(generateRandomBubble(in: size))
        }
    }

    private func updateSpikeballs(in size: CGSize) {
        var updated: [Spikeball] = []
        let padding = spikeballDiameter(in: size) * 2

        for var spikeball in spikeballs {
            spikeball.position.x += spikeball.speed.width
            spikeball.position.y += spikeball.speed.height

            if isOffscreen(spikeball.position, in: size, padding: padding) {
                continue
            }

            updated.append(spikeball)
        }

        spikeballs = updated

        if spikeballs.count < 3 && Int.random(in: 0..<90) == 0 {
            spikeballs.append(generateRandomSpikeball(in: size))
        }
    }

    private func updateMenuSize(_ size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        menuSize = size
    }

    private func spawnInitialSpikeballs(in size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }

        let count = min(3, max(1, Int((size.width * size.height) / 180000)))
        spikeballs = (0..<count).map { _ in
            let margin = spikeballDiameter(in: size) * 1.5
            let position = CGPoint(
                x: randomValue(from: margin, to: size.width - margin),
                y: randomValue(from: margin, to: size.height - margin)
            )
            let speed = CGSize(
                width: CGFloat.random(in: -0.5...0.5),
                height: CGFloat.random(in: -0.5...0.5)
            )
            return Spikeball(position: position, speed: speed)
        }
    }

    private func clearActiveEntities() {
        bubbles = []
        spikeballs = []
    }

    private func resetForMenu() {
        fadeOutOpacity = 1.0
        bubbles = []
        spawnInitialSpikeballs(in: activeMenuSize())
    }

    private func generateRandomBubble(in size: CGSize) -> Bubble {
        let start = randomMovingStart(in: size, padding: bubbleDiameter(in: size))
        let speed = CGSize(width: start.direction.dx * CGFloat.random(in: 0.5...1.5), height: start.direction.dy * CGFloat.random(in: 0.5...1.5))
        return Bubble(position: start.position, speed: speed)
    }

    private func generateRandomSpikeball(in size: CGSize) -> Spikeball {
        let start = randomMovingStart(in: size, padding: spikeballDiameter(in: size))
        let speed = CGSize(width: start.direction.dx * CGFloat.random(in: 0.5...1.0), height: start.direction.dy * CGFloat.random(in: 0.5...1.0))
        return Spikeball(position: start.position, speed: speed)
    }

    private func randomMovingStart(in size: CGSize, padding: CGFloat) -> (position: CGPoint, direction: CGVector) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let edge = Int.random(in: 0..<4)

        switch edge {
        case 0:
            return (CGPoint(x: -padding, y: CGFloat.random(in: 0...height)), CGVector(dx: 1, dy: CGFloat.random(in: -0.4...0.4)))
        case 1:
            return (CGPoint(x: width + padding, y: CGFloat.random(in: 0...height)), CGVector(dx: -1, dy: CGFloat.random(in: -0.4...0.4)))
        case 2:
            return (CGPoint(x: CGFloat.random(in: 0...width), y: -padding), CGVector(dx: CGFloat.random(in: -0.4...0.4), dy: 1))
        default:
            return (CGPoint(x: CGFloat.random(in: 0...width), y: height + padding), CGVector(dx: CGFloat.random(in: -0.4...0.4), dy: -1))
        }
    }

    private func activeMenuSize() -> CGSize {
        if menuSize.width > 0 && menuSize.height > 0 {
            return menuSize
        }

        return CGSize(width: 390, height: 844)
    }

    private func bubbleDiameter(in size: CGSize) -> CGFloat {
        min(max(size.width * 0.08, 26), 34)
    }

    private func spikeballDiameter(in size: CGSize) -> CGFloat {
        min(max(size.width * 0.105, 36), 46)
    }

    private func isOffscreen(_ point: CGPoint, in size: CGSize, padding: CGFloat) -> Bool {
        point.x < -padding || point.x > size.width + padding || point.y < -padding || point.y > size.height + padding
    }

    private func randomValue(from lowerBound: CGFloat, to upperBound: CGFloat) -> CGFloat {
        guard lowerBound < upperBound else {
            return (lowerBound + upperBound) / 2
        }

        return CGFloat.random(in: lowerBound...upperBound)
    }
}
