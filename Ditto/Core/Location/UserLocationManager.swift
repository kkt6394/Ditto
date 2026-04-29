//
//  UserLocationManager.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import CoreLocation
import Foundation
import Observation

struct UserCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

@Observable
final class UserLocationManager: NSObject {
    private(set) var currentCoordinate: UserCoordinate?
    private(set) var locationMessage: String?

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var didRequestAuthorization = false

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            guard !didRequestAuthorization else { return }
            didRequestAuthorization = true
            locationMessage = "위치 권한을 확인하고 있습니다."
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationMessage = "현재 위치 기준으로 찾는 중입니다."
            locationManager.requestLocation()
        case .denied, .restricted:
            currentCoordinate = nil
            locationMessage = "위치 권한을 허용하면 거리 기반 액티비티를 볼 수 있습니다."
        @unknown default:
            currentCoordinate = nil
            locationMessage = "현재 위치를 확인할 수 없습니다."
        }
    }
}

extension UserLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationMessage = "현재 위치 기준으로 찾는 중입니다."
            manager.requestLocation()
        case .denied, .restricted:
            currentCoordinate = nil
            locationMessage = "위치 권한을 허용하면 거리 기반 액티비티를 볼 수 있습니다."
        case .notDetermined:
            break
        @unknown default:
            currentCoordinate = nil
            locationMessage = "현재 위치를 확인할 수 없습니다."
        }
    }

    func locationManager(_ _: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationMessage = "현재 위치를 확인할 수 없습니다."
            return
        }

        currentCoordinate = UserCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        locationMessage = "현재 위치 기준으로 액티비티를 찾고 있습니다."
    }

    func locationManager(_ _: CLLocationManager, didFailWithError _: Error) {
        currentCoordinate = nil
        locationMessage = "현재 위치를 확인하지 못했습니다."
    }
}
