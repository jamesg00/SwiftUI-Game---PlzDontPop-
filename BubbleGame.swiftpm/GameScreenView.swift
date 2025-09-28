import SwiftUI
import Subsonic 
import CoreText

struct BombBubble: Identifiable {
    let id = UUID()
    var position: CGPoint
    var direction: CGVector
    var angle: CGFloat
    var speed: CGFloat
    var creationTime: Double
}

struct TimerBubble {
    var id = UUID()
    var position: CGPoint
    var angle: CGFloat
    var speed: CGFloat
    var sineOffset: CGFloat = CGFloat.random(in: 0...2 * .pi)
}

struct GameScreenView: View {
    
    
    var onBack: () -> Void
    @State private var timerBubbles: [TimerBubble] = []
    @State private var slowUntil: Double = 0
    @State private var bombBubbles: [BombBubble] = []
    @State private var bombBubblePosition: CGPoint? = nil
    @State private var isBombActive: Bool = false
    @State private var bombTimer: Timer? = nil
    @State private var bombRemainingTime: Double = 0.0
    @State private var gameOpacity: Double = 0.0
    @State private var bubblePosition: CGPoint = CGPoint(x: 200, y: 500)
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var isGameStarted: Bool = false
    @State private var sineOffset: CGFloat = 0.0
    @State private var animationTime: Double = 0.0
    @State private var showGameText: Bool = true
    @State private var titleY: CGFloat = 0.0
    @State private var sineTime: Double = 0.0
    @State private var spikes: [Spike] = []
    @State private var gameTime: Double = 0.0
    @State private var lastSpikeSpawnTime: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var dragX : CGFloat = 0.0  
    @State private var lastDragX: CGFloat = 0.0
    @State private var dragXf : CGFloat = 0.0
    @State private var lastDragXf : CGFloat = 0.0
    @ObservedObject var bgMusic: SubsonicPlayer 
    @ObservedObject var fxMusic: SubsonicPlayer
    @State private var waveOffset: CGFloat = 0.0
    @State private var isShowingFullHelp = false
    @State private var isShowingSettings = false
    @State private var isGameOver: Bool = false
    
    let sineTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    
    
    func restartGame() {
        bubblePosition = CGPoint(x: 200, y: 500)
        dragOffset = .zero
        isDragging = false
        isGameStarted = false
        showGameText = true
        sineTime = 0.0
        spikes.removeAll()
        bombBubbles.removeAll()
        bombBubblePosition = nil
        isBombActive = false
        bombTimer?.invalidate()
        bombRemainingTime = 0
        gameTime = 0.0
        lastSpikeSpawnTime = 0.0
        isPaused = false
        isGameOver = false
    } 

    
    func registerFont(withName name: String) {
        guard let fontURL = Bundle.main.url(forResource: name, withExtension: "ttf") else {
            print("Font not found in bundle")
            return
        }
        
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        print("✅ Registered font: \(name)")
    }
    
    


    
    
     
    

    var body: some View {
        
        
        ZStack {
          
            
                
            Image("sea")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(gameOpacity)
            
            if showGameText {
                Image("gametxt1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 330)
                    .position(x: 329, y: 250 + titleY)
                    .opacity(gameOpacity)
            }
            
            if  !isGameOver && !isPaused{
                ForEach(spikes) { spike in
                    Image("spikeball1")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .position(spike.position)
                }
            
            
           
               Image(isBombActive ? "bomb" : "bubbl")                    .resizable()
                    .frame(width: 50, height: 50)
                    .position(
                        x: 130 + bubblePosition.x + dragOffset.width,
                        y: bubblePosition.y + dragOffset.height + (isGameStarted ? 0 : sineOffset)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isGameOver else { return }
                                if !isGameStarted {
                                    isGameStarted = true
                                    showGameText = false
                                }
                                dragOffset = value.translation
                            }
                            .onEnded { _ in
                                guard !isGameOver else { return }
                                bubblePosition.x += dragOffset.width
                                bubblePosition.y += dragOffset.height
                                dragOffset = .zero
                            }
                    )
                    .onTapGesture {
                        if !isGameStarted {
                            isGameStarted = true
                            showGameText = false
                        }
                    }
                
                ForEach(bombBubbles) { bomb in
                    Image("bombBubbl")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .position(bomb.position)
                }
                
                ForEach(timerBubbles, id: \.id) { bubble in
                    Image("TimeBubbl") 
                        .resizable()
                        .frame(width: 50, height: 50)
                        .position(bubble.position)
                }
              
            }
            
            
             
            if isGameStarted && !isPaused && !isGameOver {
                
                if isBombActive {
                    Text("💣 Bomb: \(Int(bombRemainingTime))s")
                        .font(.custom("Futura", size: 16))
                        .foregroundColor(.black)
                        .position(x: 330, y: 80)
                }

                
                
                Text("Time: \(String(format: "%.1f", gameTime))s")
                    .font(.custom("Futura", size: 24))                    .foregroundColor(.black)
                    .shadow(radius: 2)
                    .padding()
                    .position(x: 343, y: 37)  
                
                
                Text("Time: \(String(format: "%.1f", gameTime))s")
                    .font(.custom("Futura", size: 24))                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .padding()
                    .position(x: 340, y: 35)  
            }
            
            if isShowingFullHelp {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(999)
                
                HelpWindow(showHelp: $isShowingFullHelp, fxMusic: fxMusic)
                    .zIndex(1000)
            } else if isShowingSettings {
                SettingsView(showSettings: $isShowingSettings, bgMusic: bgMusic, fxMusic: fxMusic)
            } 
            
            if isGameOver {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .zIndex(999)
                
                VStack(spacing: 30) {
                    Image("gameOvertxt")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .position(x:70, y:100) 
                        .offset(y: sin(CGFloat(sineTime * 2)) * 10)
                    
                    Image("gotomenu1")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280)
                        .position(x:75, y:10)  

                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                gameOpacity = 0.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onBack()
                            }
                        }
                    
                    Image("gotorestart1")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280)
                        .position(x:75, y:-50) 

                        .onTapGesture {
                            restartGame()
                        }
                }
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                .zIndex(1000)
            }

            // Top Bar (Back + Pause)
            VStack {
                HStack {
                    // Back Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            gameOpacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onBack()
                        }
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    // Pause Button
                    if isGameStarted {
                        Button(action: {
                            isPaused.toggle()
                        }) {
                            Image("Pause")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipped()
                        }
                        .position(x: 80, y: 38 + titleY) // top-right
                        .zIndex(10) // Make sure it's above other views
                    }
                }
                
                Spacer()
            }
            if isPaused && !isShowingFullHelp{
                // Just show the "Quit1" image, cleanly

                
                // Optional: help3 image
                Image("help3")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                    .clipped()
                    .position(x: 330, y: 550 + titleY)
                    .zIndex(100)
                    .onTapGesture {
                        withAnimation {
                            isShowingFullHelp = true
                        }
                    }
                
                Image("gotomenu1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                    .position(x: 330, y: 400 + titleY)
                    .zIndex(101)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            gameOpacity = 0.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onBack() // Already defined as a closure to go back to title
                        }
                    }
                
                
                
                //Code for images of music volume text and volumes slider. Adds play button to be moved this will contorl background music
                Image("musicvol")
                    .resizable()
                    .scaledToFit()
                    .position(x: 120, y: 100 + CGFloat(sin(waveOffset * 0.08) * 6))                 
                    .frame(width:230) 
                
                Image("volume1")
                    .resizable()   
                    .scaledToFit()   
                    .position(x: 150, y:160)
                    .frame(width:300)
                
                Image("play2")
                    .resizable()
                    .scaledToFit()
                    .position(x: -98 + dragX, y: 160) // Always based off -98 starting point
                    .frame(width: 35)
                    .zIndex(dragX == 0 ? 0 : 1)
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                let newX = lastDragX + value.translation.width
                                dragX = min(max(newX, 0), 235) // clamp between 0 and 250
                                
                                bgMusic.volume = dragX/250
                            }
                            .onEnded { _ in
                                lastDragX = dragX // lock in position
                            }
                    )
                
                
  
                
                //Same thing but for fx volume. This will control hit1.mp3    
                Image("fxvol")
                    .resizable()
                    .scaledToFit()
                    .position(x: 80, y: 230 + CGFloat(sin(waveOffset * 0.05) * 6))
                    .frame(width:160)
                
                Image("volume1")
                    .resizable()   
                    .scaledToFit()   
                    .position(x: 150, y:280)
                    .frame(width:300)
                
                Image("play2")
                    .resizable()
                    .scaledToFit()
                    .position(x:-98 + dragXf, y:280)
                    .frame(width:35)
                    .zIndex(dragXf == 0 ? 0 : 1)
                
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                let newXf = lastDragXf + value.translation.width
                                dragXf = min(max(newXf, 0), 235) // clamp between 0 and 250
                                
                                fxMusic.volume = dragXf/250
                            }
                            .onEnded { _ in
                                lastDragXf = dragXf // lock in position
                            }
                        
                    ) 
                
                    .onAppear{
                        let initialX = bgMusic.volume * 250
                        dragX = initialX
                        lastDragX = initialX
                        
                        let initialXf = fxMusic.volume * 250
                        dragXf = initialXf
                        lastDragXf = initialXf
                        
                        
                    }
                
                    .onReceive(timer) { _ in
                        waveOffset += 1
                    }
                
            
            }
            
        }
        
        // ✅ Proper Modifiers ON THE OUTER ZSTACK:
        .onAppear {
            
            
                registerFont(withName: "BigParty4Blue") // Filename 
            
            withAnimation(.easeInOut(duration: 1.0)) {
                gameOpacity = 1.0
            }
        }
        .onReceive(timer) { _ in
            guard isGameStarted && !isPaused && !isGameOver else { return }
            
            gameTime += 0.016
            
            // MARK: - Bomb Bubble Spawning
            if bombBubbles.count < 3 && Int.random(in: 0...10) == 0 {
                let screen = UIScreen.main.bounds
                let edge = Int.random(in: 0..<8)
                var pos: CGPoint
                var dir: CGVector
                
                switch edge {
                case 0: // Left
                    pos = CGPoint(x: -40, y: CGFloat.random(in: 0...screen.height))
                    dir = CGVector(dx: 1, dy: CGFloat.random(in: -0.5...0.5))
                case 1: // Right
                    pos = CGPoint(x: screen.width + 40, y: CGFloat.random(in: 0...screen.height))
                    dir = CGVector(dx: -1, dy: CGFloat.random(in: -0.5...0.5))
                case 2: // Top
                    pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: -40)
                    dir = CGVector(dx: CGFloat.random(in: -0.5...0.5), dy: 1)
                case 3: // Bottom
                    pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: screen.height + 40)
                    dir = CGVector(dx: CGFloat.random(in: -0.5...0.5), dy: -1)
                case 4: pos = CGPoint(x: -40, y: -40); dir = CGVector(dx: 1, dy: 1)
                case 5: pos = CGPoint(x: screen.width + 40, y: -40); dir = CGVector(dx: -1, dy: 1)
                case 6: pos = CGPoint(x: -40, y: screen.height + 40); dir = CGVector(dx: 1, dy: -1)
                case 7: pos = CGPoint(x: screen.width + 40, y: screen.height + 40); dir = CGVector(dx: -1, dy: -1)
                default:
                    pos = CGPoint(x: -40, y: CGFloat.random(in: 0...screen.height))
                    dir = CGVector(dx: 1, dy: 0)
                }
                
                // Normalize direction
                let mag = sqrt(dir.dx * dir.dx + dir.dy * dir.dy)
                let direction = CGVector(dx: dir.dx / mag, dy: dir.dy / mag)
                let angle = atan2(direction.dy, direction.dx)
                
                let newBomb = BombBubble(
                    position: pos,
                    direction: direction,
                    angle: angle,
                    speed: 80,
                    creationTime: gameTime
                )
                bombBubbles.append(newBomb)
            }
            
            // MARK: - Update Bomb Bubble Positions
            for i in bombBubbles.indices {
                var bomb = bombBubbles[i]
                let t = gameTime - bomb.creationTime
                let waveOffset = sin(t * 3 + bomb.angle) * 12
                
                bomb.position.x += bomb.direction.dx * bomb.speed * 0.016
                bomb.position.y += bomb.direction.dy * bomb.speed * 0.016
                
                // Apply sine wave perpendicular offset
                bomb.position.x += CGFloat(-bomb.direction.dy) * waveOffset * 0.05
                bomb.position.y += CGFloat(bomb.direction.dx) * waveOffset * 0.05
                
                bombBubbles[i] = bomb
            }
            
            // MARK: - Remove Off-Screen Bomb Bubbles
            bombBubbles.removeAll {
                $0.position.x < -100 || $0.position.x > UIScreen.main.bounds.width + 100 ||
                $0.position.y < -100 || $0.position.y > UIScreen.main.bounds.height + 100
            }
            
            if timerBubbles.count < 2 && gameTime.truncatingRemainder(dividingBy: 2) < 0.016 {                let edge = Int.random(in: 0..<4)
                var position = CGPoint(x: 0, y: 0)
                var angle: CGFloat = 0
                
                switch edge {
                case 0: // Top
                    position = CGPoint(x: CGFloat.random(in: 0...UIScreen.main.bounds.width), y: -40)
                    angle = CGFloat.random(in: 20...160)
                case 1: // Bottom
                    position = CGPoint(x: CGFloat.random(in: 0...UIScreen.main.bounds.width), y: UIScreen.main.bounds.height + 40)
                    angle = CGFloat.random(in: 200...340)
                case 2: // Left
                    position = CGPoint(x: -40, y: CGFloat.random(in: 0...UIScreen.main.bounds.height))
                    angle = CGFloat.random(in: 110...250)
                case 3: // Right
                    position = CGPoint(x: UIScreen.main.bounds.width + 40, y: CGFloat.random(in: 0...UIScreen.main.bounds.height))
                    angle = CGFloat.random(in: -70...70)
                default:
                    break
                }
                
                let newBubble = TimerBubble(position: position, angle: angle, speed: 1.5)
                timerBubbles.append(newBubble)
            }
            
            for i in timerBubbles.indices {
                var bubble = timerBubbles[i]
                let angle = bubble.angle * .pi / 180
                let dx = cos(angle) * bubble.speed
                let dy = sin(angle) * bubble.speed
                let sineMovement = sin(bubble.sineOffset + CGFloat(gameTime) * 2.5) * 2.0
                
                bubble.position.x += dx + sineMovement
                bubble.position.y += dy + sineMovement
                
                timerBubbles[i] = bubble
            } 
            
            for (index, bubble) in timerBubbles.enumerated().reversed() {
                let distance = hypot(bubble.position.x - bubblePosition.x, bubble.position.y - bubblePosition.y)
                if distance < 50 {
                    // Collected power-up: slow down spikes
                    slowUntil = gameTime + 5
                    timerBubbles.remove(at: index)
                    fxMusic.play() 
                }
            }
            
            // MARK: - Spike Spawning
            let maxSpawnInterval = 0.5
            let minSpawnInterval = 0.02
            let spawnInterval = max(maxSpawnInterval - gameTime * 0.02, minSpawnInterval)
            
            if gameTime - lastSpikeSpawnTime > spawnInterval && spikes.count < 50 {
                lastSpikeSpawnTime = gameTime
                
                let screen = UIScreen.main.bounds
                let edge = Int.random(in: 0..<8)
                var pos: CGPoint
                var dir: CGVector
                
                switch edge {
                case 0:
                    pos = CGPoint(x: -50, y: CGFloat.random(in: 0...screen.height))
                    dir = CGVector(dx: 1, dy: CGFloat.random(in: -0.5...0.5))
                case 1:
                    pos = CGPoint(x: screen.width + 50, y: CGFloat.random(in: 0...screen.height))
                    dir = CGVector(dx: -1, dy: CGFloat.random(in: -0.5...0.5))
                case 2:
                    pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: -50)
                    dir = CGVector(dx: CGFloat.random(in: -0.5...0.5), dy: 1)
                case 3:
                    pos = CGPoint(x: CGFloat.random(in: 0...screen.width), y: screen.height + 50)
                    dir = CGVector(dx: CGFloat.random(in: -0.5...0.5), dy: -1)
                case 4: pos = CGPoint(x: -50, y: -50); dir = CGVector(dx: 1, dy: 1)
                case 5: pos = CGPoint(x: screen.width + 50, y: -50); dir = CGVector(dx: -1, dy: 1)
                case 6: pos = CGPoint(x: -50, y: screen.height + 50); dir = CGVector(dx: 1, dy: -1)
                case 7: pos = CGPoint(x: screen.width + 50, y: screen.height + 50); dir = CGVector(dx: -1, dy: -1)
                default:
                    pos = CGPoint(x: -50, y: CGFloat.random(in: 0...screen.height))
                    dir = CGVector(dx: 1, dy: 0)
                }
                
                let mag = sqrt(dir.dx * dir.dx + dir.dy * dir.dy)
                let direction = CGVector(dx: dir.dx / mag, dy: dir.dy / mag)
                let angle = atan2(direction.dy, direction.dx)
                
                let baseSpeed: CGFloat = 60
                let maxSpeed: CGFloat = 600
                let difficultyScale = min(1.0, CGFloat(gameTime / 60))
                let speed = CGFloat.random(in: baseSpeed...(baseSpeed + (maxSpeed - baseSpeed) * difficultyScale))
               
                let newSpike = Spike(
                    position: pos,
                    direction: direction,
                    angle: angle,
                    speed: speed,
                    creationTime: gameTime
                )
                spikes.append(newSpike)
            }
            
            let isSlowed = gameTime < slowUntil
            let spikeSpeedMultiplier: CGFloat = isSlowed ? 0.4 : 1.0 
            // MARK: - Update Spike Positions
            for i in spikes.indices {
                var spike = spikes[i]
                let t = gameTime - spike.creationTime
                let waveOffset = sin(t * 3 + spike.angle) * 12
                
                spike.position.x += spike.direction.dx * spike.speed * 0.016 * spikeSpeedMultiplier
                spike.position.y += spike.direction.dy * spike.speed * 0.016 * spikeSpeedMultiplier
                
                spike.position.x += CGFloat(-spike.direction.dy) * waveOffset * 0.05
                spike.position.y += CGFloat(spike.direction.dx) * waveOffset * 0.05
                
                spikes[i] = spike
            }
            
            spikes.removeAll {
                $0.position.x < -100 || $0.position.x > UIScreen.main.bounds.width + 100 ||
                $0.position.y < -100 || $0.position.y > UIScreen.main.bounds.height + 100
            }
        }
        .onReceive(sineTimer) { _ in
                
            guard !isGameOver else { return }
            sineTime += 0.016
            titleY = sin(sineTime * 2) * 10
            
            // Check collision with bubble
            let bubbleFrame = CGRect(
                x: 130 + bubblePosition.x + dragOffset.width - 25,
                y: bubblePosition.y + dragOffset.height - 25,
                width: 50,
                height: 50
            )
            
            for spike in spikes {
                let spikeFrame = CGRect(
                    x: spike.position.x - 25,
                    y: spike.position.y - 25,
                    width: 50,
                    height: 50
                )
                
                if bubbleFrame.intersects(spikeFrame) {
                    if isBombActive {
                        if let index = spikes.firstIndex(where: { $0.id == spike.id }) {
                            spikes.remove(at: index)
                        }
                    } else if !isGameOver {
                        fxMusic.play()
                        isGameOver = true
                        isGameStarted = false
                        break
                    }
                }
            }
            for (i, bomb) in bombBubbles.enumerated().reversed() {
                let bombFrame = CGRect(x: bomb.position.x - 20, y: bomb.position.y - 20, width: 40, height: 40)
                
                if bubbleFrame.intersects(bombFrame) {
                    isBombActive = true
                    bombRemainingTime = 5.0
                    bombBubbles.remove(at: i)
                    
                    bombTimer?.invalidate()
                    bombTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        bombRemainingTime -= 1
                        if bombRemainingTime <= 0 {
                            isBombActive = false
                            bombTimer?.invalidate()
                        }
                    }
                }
            }
        }
        
 
    }

}

