import SwiftUI

struct ContentView: View {






    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
            Text("Spatial Object Drums").font(.largeTitle.bold())
            Text("Apple 샘플과 대응하는 Magic Keyboard를 평평한 테이블에 놓으세요.")
                .multilineTextAlignment(.center)
            Label("키보드 위의 초록색 가상 타격면을 손가락으로 통과하세요.", systemImage: "hand.tap")
                .foregroundStyle(.secondary)
            Label("Apple Vision Pro 실기기와 정리된 주변 공간이 필요합니다.", systemImage: "visionpro")
                .foregroundStyle(.secondary)
            Label("인식되면 키보드 위와 몰입 화면 상단에 초록색 표시가 나타납니다.", systemImage: "viewfinder")
                .foregroundStyle(.secondary)

            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }






















































        .padding(40)
        .frame(width: 620, height: 460)
    }






    }
}
