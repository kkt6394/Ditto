//
//  ActivityComposeLocationSection.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import MapKit
import SwiftUI

// MapKit 지도를 띄우고 화면 정중앙 핀(SF Symbol)을 시각적으로 고정한다.
// 사용자는 지도를 움직여 핀을 원하는 위치에 맞추고, 카메라 변경이 끝나면 좌표가 ViewModel에 반영된다.
struct ActivityComposeLocationSection: View {
    let viewModel: ActivityComposeViewModel
    @State private var cameraPosition: MapCameraPosition

    init(viewModel: ActivityComposeViewModel) {
        self.viewModel = viewModel
        let center = CLLocationCoordinate2D(
            latitude: viewModel.latitude ?? Self.defaultLatitude,
            longitude: viewModel.longitude ?? Self.defaultLongitude
        )
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        self._cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "위치")

            ZStack {
                Map(position: $cameraPosition)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(PostComposePalette.inputBorder, lineWidth: 1)
                    )
                    .onMapCameraChange(frequency: .onEnd) { context in
                        let center = context.region.center
                        viewModel.latitude = center.latitude
                        viewModel.longitude = center.longitude
                    }

                centerPin
            }

            coordinateLabel
        }
    }

    // 핀 자체는 시각 가이드일 뿐 입력은 카메라 중심으로만 결정된다.
    private var centerPin: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(MainScreenPalette.primaryBlue)
            .padding(4)
            .background(Circle().fill(.white))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var coordinateLabel: some View {
        if let latitude = viewModel.latitude, let longitude = viewModel.longitude {
            Text(String(format: "위도 %.5f, 경도 %.5f", latitude, longitude))
                .font(MainScreenTypography.bodyCompact)
                .foregroundStyle(MainScreenPalette.textSecondary)
        } else {
            Text("지도를 움직여 위치를 선택하세요.")
                .font(MainScreenTypography.bodyCompact)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
    }

    // 좌표가 비어 있을 때의 시작점 — 서울 시청 인근.
    private static let defaultLatitude: Double = 37.5665
    private static let defaultLongitude: Double = 126.9780
}
