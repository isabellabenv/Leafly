//
//  profilePage.swift
//  test
//
//  Created by Isabella Benvenuto on 23/6/2025.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Profile Header
            VStack {
                HStack {
                    Image("profile_photo") // Replace with actual image asset
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .padding(.leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amélie Dean")
                            .font(.headline)
                        Text("@Deanosaurrr")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        ProgressView(value: 0.75)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(width: 100)
                        Text("level 27")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "ellipsis")
                        .padding()
                }

                HStack {
                    Spacer()
                    VStack {
                        Text("232")
                            .bold()
                        Text("Followers")
                            .font(.caption)
                    }
                    Spacer()
                    VStack {
                        Text("2124")
                            .bold()
                        Text("Following")
                            .font(.caption)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
            }
            .background(Color.ggreen)

            // Tabs
            HStack {
                Text("All Posts").bold()
                Spacer()
                Text("Photos")
                Spacer()
                Text("Awards")
            }
            .padding()
            .background(Color.palegreen)

            // Posts
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PostView(profileImage: "profile_photo", name: "Amelie Dean", time: "2 hours ago", action: "Used a reusable bag", quote: "So glad I didn’t have to pay 50c", points: "+10")
                    
                    PostView(profileImage: "profile_photo", name: "Amelie Dean", time: "4 hours ago", action: "Repurposed an old shirt", quote: "Didn’t want to throw it out", points: "+50", postImage: "repurposed_shirt")
                }
                .padding()
            }

            // Bottom Navigation
            HStack {
                Spacer(minLength: 20)
                Image(systemName: "house")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .padding()
                Spacer()
                ZStack {
                    Circle()
                        .foregroundColor(.darkgreen)
                        .frame(width: 80, height: 80)
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 50))
                }
                .padding()
                Spacer()
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.white)
                    .font(.system(size: 40))
                    .padding()
                Spacer(minLength: 20)
            }
            .padding()
            .frame(width: .infinity, height: 100)
            .background(Color.ggreen)
        }
    }
}

struct PostView: View {
    var profileImage: String
    var name: String
    var time: String
    var action: String
    var quote: String
    var points: String
    var postImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(name)
                            .bold()
                        Spacer()
                        Text(time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text(action)
                    Text("“\(quote)”")
                        .italic()
                        .font(.caption)

                    Text("\(points) points")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            if let postImage = postImage {
                Image(postImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                    .padding(.leading, 44) // aligned with text
            }
        }
    }
}

#Preview {
    ProfileView()
}
