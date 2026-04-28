//
//  MainView.swift
//  Ditto
//
//  Created by 김기태 on 4/24/26.
//

import SwiftUI

struct MainView: View {
    private let authManager: any AuthManaging

    @State private var viewModel: MainViewModel
    @State private var selectedCountryID = MainCountryFilter.samples[0].id
    @State private var selectedCategoryID = MainCategoryFilter.samples[0].id
    @State private var selectedTabID = MainTab.home.rawValue
    @State private var locationManager = UserLocationManager()
    @State private var activityPostDistanceKilometers = 3.0
    @State private var signOutMessage: String?

    init(authManager: any AuthManaging) {
        self.authManager = authManager
        _viewModel = State(initialValue: MainViewModel(authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            MainScreenPalette.background
                .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainBottomTabBar(
                items: MainTabItem.samples,
                selectedID: selectedTabID
            ) { item in
                selectedTabID = item.id
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch MainTab(rawValue: selectedTabID) {
        case .profile:
            ProfileTabView(
                signOutMessage: signOutMessage,
                signOutAction: signOut
            )
        default:
            homeTab
        }
    }

    private var homeTab: some View {
        VStack(spacing: 0) {
            fixedHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MainSectionTitleRow(
                        title: "NEW 액티비티",
                        trailingTitle: "View All"
                    )
                    .padding(.top, 26)

                    NewActivityContent(
                        items: viewModel.newActivities,
                        isLoading: viewModel.isLoadingNewActivities,
                        message: viewModel.newActivitiesMessage
                    )
                        .padding(.top, 12)

                    MainBannerContent(
                        banners: viewModel.mainBanners,
                        isLoading: viewModel.isLoadingMainBanners,
                        message: viewModel.mainBannersMessage
                    )
                    .padding(.top, 16)

                    ActivityPostsSection(
                        posts: viewModel.activityPosts,
                        isLoading: viewModel.isLoadingActivityPosts,
                        message: viewModel.activityPostsMessage,
                        distanceKilometers: $activityPostDistanceKilometers,
                        locationMessage: locationManager.locationMessage
                    )
                        .padding(.top, 24)
                }
                .padding(.bottom, 24)
            }
            .task {
                locationManager.requestCurrentLocation()
            }
            .task(id: newActivitiesQueryID) {
                await viewModel.loadNewActivities(
                    country: selectedCountryName,
                    category: selectedCategoryTitle
                )
            }
            .task {
                await viewModel.loadMainBanners()
            }
            .task(id: activityPostsQueryID) {
                // 슬라이더 조작 중에는 이전 task가 취소되므로, 멈춘 뒤 한 번만 조회한다.
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }

                await viewModel.loadActivityPosts(
                    country: selectedCountryName,
                    category: selectedCategoryTitle,
                    coordinate: locationManager.currentCoordinate,
                    maxDistanceMeters: selectedDistanceMeters
                )
            }
        }
    }

    private var fixedHeader: some View {
        VStack(spacing: 0) {
            MainTopBar()
                .padding(.horizontal, 20)
                .padding(.top, 12)

            CountryFilterCarousel(
                items: MainCountryFilter.samples,
                selectedID: $selectedCountryID
            )
            .padding(.top, 8)

            CategoryFilterCarousel(
                items: MainCategoryFilter.samples,
                selectedID: $selectedCategoryID
            )
            .padding(.top, 6)
        }
    }

    private func signOut() {
        do {
            try authManager.signOut()
        } catch {
            signOutMessage = "로그아웃 처리에 실패했습니다."
        }
    }

    private var selectedCountryName: String? {
        MainCountryFilter.samples.first { $0.id == selectedCountryID }?.name
    }

    private var selectedCategoryTitle: String? {
        MainCategoryFilter.samples.first { $0.id == selectedCategoryID }?.title
    }

    private var newActivitiesQueryID: String {
        "\(selectedCountryID)-\(selectedCategoryID)"
    }

    private var activityPostsQueryID: String {
        "\(newActivitiesQueryID)-\(selectedDistanceMeters)-\(locationCoordinateID)"
    }

    private var selectedDistanceMeters: Int {
        Int(activityPostDistanceKilometers.rounded()) * 1_000
    }

    private var locationCoordinateID: String {
        guard let coordinate = locationManager.currentCoordinate else {
            return "no-location"
        }

        let latitude = Int((coordinate.latitude * 10_000).rounded())
        let longitude = Int((coordinate.longitude * 10_000).rounded())
        return "\(latitude)-\(longitude)"
    }
}

#Preview {
    MainView(authManager: AuthManager())
}
