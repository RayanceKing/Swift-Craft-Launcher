import SwiftUI

struct FriendsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("experimental.friends.coming_soon".localized())
                .font(.title2.weight(.medium))
                .foregroundColor(.secondary)
            Text("experimental.friends.description".localized())
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
