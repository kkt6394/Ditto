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
    @State private var searchViewResetID = UUID()
    @State private var locationManager = UserLocationManager()
    @State private var signOutMessage: String?
    @State private var navigationPath = NavigationPath()
    @State private var selectedMedia: MainPostMedia?
    @State private var homeScrollToTopTrigger = false
    @State private var pendingChatOpponentIDs: Set<String> = []
    @State private var isPresentingPostComposer = false

    init(authManager: any AuthManaging) {
        self.authManager = authManager
        _viewModel = State(initialValue: MainViewModel(authManager: authManager))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack(path: $navigationPath) {
                VStack(spacing: 0) {
                    content
                }
                .background(
                    MainScreenPalette.background
                        .ignoresSafeArea()
                )
                .navigationDestination(for: MainRoute.self) { route in
                    destination(for: route)
                }
            }
            .fullScreenCover(item: $selectedMedia) { media in
                ActivityPostMediaViewer(media: media, authManager: authManager)
            }
            .sheet(isPresented: $isPresentingPostComposer) {
                PostComposeView(
                    initialContext: makeComposerContext(),
                    authManager: authManager
                ) {
                    Task { await reloadActivityPostsAfterCompose() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if navigationPath.isEmpty {
                    MainBottomTabBar(
                        items: MainTabItem.samples,
                        selectedID: selectedTabID
                    ) { item in
                        selectTab(item)
                    }
                }
            }

            if shouldShowComposerButton {
                PostComposeFloatingButton {
                    isPresentingPostComposer = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 88)
            }
        }
    }

    private var shouldShowComposerButton: Bool {
        navigationPath.isEmpty && selectedTabID == MainTab.home.rawValue
    }

    private func makeComposerContext() -> PostComposeInitialContext {
        PostComposeInitialContext(
            country: selectedCountryName ?? MainCountryFilter.samples[0].name,
            category: selectedCategoryTitle ?? MainCategoryFilter.samples[0].title,
            coordinate: locationManager.currentCoordinate
        )
    }

    private func reloadActivityPostsAfterCompose() async {
        await viewModel.loadActivityPosts(
            country: selectedCountryName,
            category: selectedCategoryTitle
        )
    }

    @ViewBuilder
    private var content: some View {
        TabView(selection: $selectedTabID) {
            homeTab
                .tag(MainTab.home.rawValue)

            SearchView(authManager: authManager) { activityId in
                openActivityDetail(activityId: activityId)
            }
                .id(searchViewResetID)
                .tag(MainTab.explore.rawValue)

            VStack {
                Spacer()
                Text("좋아요 탭 준비 중")
                    .font(MainScreenTypography.sectionTitle)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                Spacer()
            }
            .tag(MainTab.likes.rawValue)

            ProfileTabView(
                signOutMessage: signOutMessage,
                signOutAction: signOut
            )
            .tag(MainTab.profile.rawValue)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var homeTab: some View {
        VStack(spacing: 0) {
            fixedHeader

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .id("homeTop")

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
                            mediaAction: { media in
                                selectedMedia = media
                            },
                            detailAction: { post in
                                openActivityDetail(for: post)
                            },
                            chatAction: { post in
                                startChat(with: post)
                            }
                        )
                        .padding(.top, 24)

                        if let chatStartMessage = viewModel.chatStartMessage {
                            Text(chatStartMessage)
                                .font(MainScreenTypography.body)
                                .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .onChange(of: homeScrollToTopTrigger) {
                    withAnimation {
                        proxy.scrollTo("homeTop", anchor: .top)
                    }
                }
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
            .task(id: newActivitiesQueryID) {
                await viewModel.loadActivityPosts(
                    country: selectedCountryName,
                    category: selectedCategoryTitle
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

    private func selectTab(_ item: MainTabItem) {
        navigationPath = NavigationPath()

        if selectedTabID == item.id {
            if MainTab(rawValue: item.id) == .explore {
                searchViewResetID = UUID()
            } else if MainTab(rawValue: item.id) == .home {
                homeScrollToTopTrigger.toggle()
            }
        }

        selectedTabID = item.id
    }

    @ViewBuilder
    private func destination(for route: MainRoute) -> some View {
        switch route {
        case .activityDetail(let activityId):
            ActivityDetailView(activityId: activityId, authManager: authManager) { roomId, opponentNick in
                navigationPath.append(MainRoute.chat(roomId: roomId, opponentNick: opponentNick))
            }
        case .chat(let roomId, let opponentNick):
            ChatRoomView(roomId: roomId, opponentNick: opponentNick, authManager: authManager)
        }
    }

    private func openActivityDetail(for post: MainActivityPost) {
        // 포스트가 액티비티 ID를 포함하지 않는 경우, 요청된 디자인 Node ID 상세로 연결한다.
        navigationPath.append(MainRoute.activityDetail(activityId: post.activityId ?? "DXWNE"))
    }

    private func openActivityDetail(activityId: String) {
        navigationPath.append(MainRoute.activityDetail(activityId: activityId))
    }

    private func startChat(with post: MainActivityPost) {
        guard pendingChatOpponentIDs.insert(post.creatorId).inserted else {
            return
        }

        Task { @MainActor in
            defer {
                pendingChatOpponentIDs.remove(post.creatorId)
            }

            guard let room = await viewModel.createChatRoom(opponentId: post.creatorId) else {
                return
            }

            navigationPath.append(MainRoute.chat(roomId: room.roomId, opponentNick: post.author))
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
}

private enum MainRoute: Hashable {
    case activityDetail(activityId: String)
    case chat(roomId: String, opponentNick: String)
}

#Preview {
    MainView(authManager: AuthManager())
}
