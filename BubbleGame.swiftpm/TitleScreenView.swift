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
    @State private var hasStartedMusic = false
    @State private var fadeOutOpacity: Double = 1.0
    @StateObject private var bgMusic = SubsonicPlayer(sound: "CatOnWindow105.mp3", volume: 0.7, repeatCount: .continuous) 
    @StateObject private var fxMusic = SubsonicPlayer(sound: "hit1.mp3", volume: 0.7)

    
    @State private var bubbles: [Bubble] = []
    @State private var spikeballs: [Spikeball] = [] 
    
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if showHelp {
                HelpWindow(showHelp: $showHelp, fxMusic: fxMusic)
            } else if showSettings {
                SettingsView(showSettings: $showSettings, bgMusic: bgMusic, fxMusic: fxMusic)
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
                    fxMusic: fxMusic
                ) 
            } else {
                mainMenuView
            }
        } 
        .onAppear {
            if !hasStartedMusic {
                bgMusic.play()
                hasStartedMusic = true
            }
        
            spawnInitialSpikeballs()
            bubbles = []
        }
        .onReceive(timer) { _ in
            // Only animate when actually on title screen
            if !isGameStarted && !showHelp && !showSettings {
                waveOffset += 0.08
                updateBubbles()
                updateSpikeballs()
            }
        }
    }
    
    // MARK: - Main Menu View
    var mainMenuView: some View {
        ZStack {
            Image("sea")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(fadeOutOpacity)
            
            // Bubbles
            ForEach(bubbles) { bubble in
                Image("bubbl")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .position(bubble.position)
                    .opacity(bubble.opacity)
                    .opacity(fadeOutOpacity)
            }
            
            // Spikeballs
            ForEach(spikeballs) { spike in
                Image("spikeball1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .position(spike.position)
                    .opacity(0.8)
                    .opacity(fadeOutOpacity)
            }
            
            VStack {
                Spacer()
                Image("titlefont1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                    .offset(y: sin(waveOffset) * 2)
                    .opacity(fadeOutOpacity)
                Spacer()
                VStack(spacing: 30) {
                    sineWaveButton(imageName: "start1", phase: 0) {
                        fxMusic.play()
                        withAnimation(.easeInOut(duration: 1.0)) {
                            fadeOutOpacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation {
                                isGameStarted = true
                            }
                            clearActiveEntities()
                        }
                    }
                    .opacity(fadeOutOpacity)
                    sineWaveButton(imageName: "settings2", phase: 1) {
                        showSettings = true
                        clearActiveEntities()
                    }
                    .opacity(fadeOutOpacity)
                    sineWaveButton(imageName: "help3", phase: 2) {
                        showHelp = true
                        clearActiveEntities()
                    }
                    .opacity(fadeOutOpacity)
                }
                Spacer()
            }
        }
    }
    
    func sineWaveButton(imageName: String, phase: Double, action: @escaping () -> Void) -> some View {
        Button(action: {
            fxMusic.play()
            action()
        }) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 280)
                .offset(y: CGFloat(sin(waveOffset + phase) * 7))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bubble Logic
    func updateBubbles() {
        let screen = UIScreen.main.bounds
        var updated: [Bubble] = []
        
        for var b in bubbles {
            b.position.x += b.speed.width
            b.position.y += b.speed.height
            
            if b.position.x < -50 || b.position.x > screen.width + 50 || b.position.y < -50 || b.position.y > screen.height + 50 {
                continue
            }
            
            let collided = spikeballs.contains {
                hypot($0.position.x - b.position.x, $0.position.y - b.position.y) < 25
            }
            
            if !collided {
                updated.append(b)
            }
        }
        
        bubbles = updated
        
        if Int.random(in: 0..<10) == 0 {
            bubbles.append(generateRandomBubble())
        }
    }
    
    func updateSpikeballs() {
        let screen = UIScreen.main.bounds
        var updated: [Spikeball] = []
        
        for var s in spikeballs {
            s.position.x += s.speed.width
            s.position.y += s.speed.height
            
            if s.position.x < -50 || s.position.x > screen.width + 50 ||
                s.position.y < -50 || s.position.y > screen.height + 50 {
                continue
            }
            updated.append(s)
        }
        
        spikeballs = updated
        
        if Int.random(in: 0..<20) == 0 {
            spikeballs.append(generateRandomSpikeball())
        }
    }
    
    // MARK: - Initialization & Clearing
    func spawnInitialSpikeballs() {
        let screen = UIScreen.main.bounds
        let count = Int((screen.width * screen.height) / 60000)
        spikeballs = (0..<count).map { _ in
            let pos = CGPoint(x: CGFloat.random(in: 60...(screen.width - 60)),
                              y: CGFloat.random(in: 60...(screen.height - 60)))
            let spd = CGSize(width: CGFloat.random(in: -0.5...0.5),
                             height: CGFloat.random(in: -0.5...0.5))
            return Spikeball(position: pos, speed: spd)
        }
    }
    
    func clearActiveEntities() {
        bubbles = []
        spikeballs = []
    }
    
    func resetForMenu() {
        bubbles = []
        spawnInitialSpikeballs()
    }
    
    // MARK: - Generators
    func generateRandomBubble() -> Bubble {
        let screen = UIScreen.main.bounds
        let edge = Int.random(in: 0..<4)
        var pos: CGPoint
        var spd: CGSize
        
        switch edge {
        case 0: pos = CGPoint(x: -30, y: CGFloat.random(in: 0...screen.height))
            spd = CGSize(width: CGFloat.random(in: 0.5...1.5), height: CGFloat.random(in: -0.5...0.5))
        case 1: pos = CGPoint(x: screen.width + 30, y: CGFloat.random(in: 0...screen.height))
            spd = CGSize(width: CGFloat.random(in: -1.5 ... -0.5), height: CGFloat.random(in: -0.5...0.5))
        case 2: pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: -30)
            spd = CGSize(width: CGFloat.random(in: -0.5...0.5), height: CGFloat.random(in: 0.5...1.5))
        default: pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: screen.height + 30)
            spd = CGSize(width: CGFloat.random(in: -0.5...0.5), height: CGFloat.random(in: -1.5 ... -0.5))
        }
        return Bubble(position: pos, speed: spd)
    }
    
    func generateRandomSpikeball() -> Spikeball {
        let screen = UIScreen.main.bounds
        let edge = Int.random(in: 0..<4)
        var pos: CGPoint
        var spd: CGSize
        
        switch edge {
        case 0: pos = CGPoint(x: -40, y: CGFloat.random(in: 0...screen.height))
            spd = CGSize(width: CGFloat.random(in: 0.5...1.0), height: CGFloat.random(in: -0.3...0.3))
        case 1: pos = CGPoint(x: screen.width + 40, y: CGFloat.random(in: 0...screen.height))
            spd = CGSize(width: CGFloat.random(in: -1.0 ... -0.5), height: CGFloat.random(in: -0.3...0.3))
        case 2: pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: -40)
            spd = CGSize(width: CGFloat.random(in: -0.3...0.3), height: CGFloat.random(in: 0.5...1.0))
        default: pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: screen.height + 40)
            spd = CGSize(width: CGFloat.random(in: -0.3...0.3), height: CGFloat.random(in: -1.0 ... -0.5))
        }
        return Spikeball(position: pos, speed: spd)
    }
}
