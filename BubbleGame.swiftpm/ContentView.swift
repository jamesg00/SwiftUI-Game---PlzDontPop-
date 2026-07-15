import SwiftUI

struct ContentView: View {
    var body: some View {
        TitleScreenView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
    }
}
