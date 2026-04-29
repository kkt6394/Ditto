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

// 좌표 → 도시명 reverse geocoding 결과를 캐시해 카드 표시 시 중복 호출을 줄인다.
actor CityResolver {
    static let shared = CityResolver()

    private struct CacheKey: Hashable {
        let latitude: Int
        let longitude: Int
    }

    private let geocoder = CLGeocoder()
    private let preferredLocale = Locale(identifier: "ko_KR")
    private var cache: [CacheKey: String?] = [:]

    private init() {}

    func city(latitude: Double, longitude: Double) async -> String? {
        let key = makeCacheKey(latitude: latitude, longitude: longitude)
        if let cached = cache[key] {
            return cached
        }

        let resolved = await reverseGeocodeCity(latitude: latitude, longitude: longitude)
        cache[key] = resolved
        return resolved
    }

    // 소수점 두 자리(약 1km) 단위로 묶어 같은 지역을 한 번만 조회한다.
    private func makeCacheKey(latitude: Double, longitude: Double) -> CacheKey {
        CacheKey(
            latitude: Int((latitude * 100).rounded()),
            longitude: Int((longitude * 100).rounded())
        )
    }

    private func reverseGeocodeCity(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: preferredLocale
            )
            return Self.cityName(from: placemarks.first)
        } catch {
            return nil
        }
    }

    private static func cityName(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }

        let candidates: [String?] = [
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea
        ]

        return candidates.lazy
            .compactMap { name -> String? in
                guard let name, !name.isEmpty else { return nil }
                return name
            }
            .first
    }
}
