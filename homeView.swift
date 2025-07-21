import SwiftUI

struct HomeView: View {
    @State private var selection: Int = 0

        var body: some View {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Welcome Back,")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Leafly User")
                            .font(.title)
                            .bold()
                    }
                    Spacer()
                    Image(systemName: "leafly")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.ggreen)

                // Featured Post or Tip
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stories")
                        .font(.headline)
                    Text("Reuse before you recycle. Small changes add up!")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.palegreen)
                .cornerRadius(12)
                .padding()

                // Recent Posts
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(0..<5) { _ in
                            PostCardView()
                        }
                    }
                    .padding()
                }

                // Bottom Toolbar
               
            }
            .navigationBarHidden(true)
        }
    }
struct PostCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "leaf")
                            .foregroundColor(.green)
                    )
                VStack(alignment: .leading) {
                    Text("EcoUser123")
                        .font(.headline)
                    Text("2 hours ago")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            Text("Planted 3 trees today in the local park! 🌳🌱")
                .font(.body)

            Image("nature-placeholder") // Replace with actual image from assets
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .cornerRadius(10)
                .clipped()

            HStack {
                Image(systemName: "leaf.circle")
                Text("+25 Green Points")
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
#Preview {
    HomeView()
}
