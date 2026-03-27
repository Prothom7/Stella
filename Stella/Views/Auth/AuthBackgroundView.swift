import SwiftUI

struct AuthBackgroundView: View {
    let width: CGFloat
    let height: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    let horizontalInsetLeading: CGFloat
    let horizontalInsetTrailing: CGFloat

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("img_02")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: (width + horizontalInsetLeading + horizontalInsetTrailing) * 1.08,
                    height: (height + topInset + bottomInset) * 1.08
                )
                .clipped()
                .ignoresSafeArea()

            Color.black.opacity(0.45)
                .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: width * 0.62, height: width * 0.62)
                .offset(x: width * 0.33, y: -height * 0.28)
                .blur(radius: 12)

            Circle()
                .fill(.blue.opacity(0.12))
                .frame(width: width * 0.52, height: width * 0.52)
                .offset(x: -width * 0.36, y: height * 0.29)
                .blur(radius: 14)
        }
    }
}
