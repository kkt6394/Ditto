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
    @State private var keepStore: KeepStore
    @Namespace private var likesHeroNamespace
    @State private var selectedCountryID = MainCountryFilter.samples[0].id
    @State private var selectedCategoryID = MainCategoryFilter.samples[0].id
    @State private var selectedTabID = MainTab.home.rawValue
    @State private var searchViewResetID = UUID()
    @State private var signOutMessage: String?
    @State private var navigationPath: [MainRoute] = []
    @State private var selectedMedia: MainPostMedia?
    @State private var homeScrollToTopTrigger = false
    @State private var pendingChatOpponentIDs: Set<String> = []
    @State private var isPresentingPostComposer = false

    init(authManager: any AuthManaging) {
        self.authManager = authManager
        _viewModel = State(initialValue: MainViewModel(authManager: authManager))
        _keepStore = State(initialValue: KeepStore(authManager: authManager))
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
                if shouldShowTabBar {
                    MainBottomTabBar(
                        items: MainTabItem.samples,
                        selectedID: selectedTabID
                    ) { item in
                        selectTab(item)
                    }
                }
            }
            // 탭바가 숨겨진 화면(예: 액티비티 상세)에서도 비행 destination을 가질 수 있도록
            // 좋아요 탭이 위치할 자리에 보이지 않는 phantom anchor를 발행한다.
            .overlay {
                GeometryReader { proxy in
                    if !shouldShowTabBar {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .position(
                                x: proxy.size.width * 0.7,
                                y: proxy.size.height - 30
                            )
                            .anchorPreference(
                                key: ActivityHeartAnchorKey.self,
                                value: .center
                            ) { anchor in
                                [ActivityHeartAnchorKey.tabSentinelID: anchor]
                            }
                    }
                }
                .allowsHitTesting(false)
            }
            .overlayPreferenceValue(ActivityHeartAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    if let flightID = keepStore.pendingFlightID,
                       let sourceAnchor = anchors[flightID],
                       let destAnchor = anchors[ActivityHeartAnchorKey.tabSentinelID] {
                        FlyingHeart(
                            source: proxy[sourceAnchor],
                            destination: proxy[destAnchor],
                            onComplete: {
                                keepStore.finishFlightAnimation(activityId: flightID)
                            }
                        )
                        .id(flightID)
                    }
                }
                .allowsHitTesting(false)
            }

            if shouldShowComposerButton {
                PostComposeFloatingButton {
                    isPresentingPostComposer = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 88)
            }
        }
        .environment(keepStore)
        .environment(\.likesHeroNamespace, likesHeroNamespace)
        .onAppear {
            updateChatPresence()
        }
        .onChange(of: selectedTabID) { _, _ in
            updateChatPresence()
        }
        .onChange(of: navigationPath.count) { _, _ in
            updateChatPresence()
        }
    }

    private func updateChatPresence() {
        // 채팅 탭 루트(목록 화면) 노출 시점에만 무음 플래그를 켠다. 채팅방 진입 시엔 ChatRoomView가 activeRoomId를 갱신한다.
        let isOnChatListRoot = selectedTabID == MainTab.chat.rawValue && navigationPath.isEmpty
        ChatPresence.shared.isOnChatList = isOnChatListRoot
    }

    private var shouldShowComposerButton: Bool {
        navigationPath.isEmpty && selectedTabID == MainTab.home.rawValue
    }

    // 카테고리 리스트 화면도 검색 탭의 연장으로 보고 탭바를 유지한다.
    private var shouldShowTabBar: Bool {
        guard let last = navigationPath.last else {
            return true
        }

        if case .searchCategory = last {
            return true
        }

        return false
    }

    private func makeComposerContext() -> PostComposeInitialContext {
        PostComposeInitialContext(
            country: selectedCountryName ?? MainCountryFilter.samples[0].name,
            category: selectedCategoryTitle ?? MainCategoryFilter.samples[0].title
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

            SearchView(
                authManager: authManager,
                activityDetailAction: { activityId in
                    openActivityDetail(activityId: activityId)
                },
                categorySelectedAction: { category in
                    navigationPath.append(MainRoute.searchCategory(category))
                }
            )
                .id(searchViewResetID)
                .tag(MainTab.explore.rawValue)

            ChatListView(authManager: authManager) { roomId, opponentNick in
                navigationPath.append(MainRoute.chat(roomId: roomId, opponentNick: opponentNick))
            }
            .tag(MainTab.chat.rawValue)

            LikesView { activityId in
                openActivityDetail(activityId: activityId)
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

                        MainSectionTitleRow(title: "NEW 액티비티")
                            .padding(.top, 26)

                        NewActivityContent(
                            items: viewModel.newActivities,
                            isLoading: viewModel.isLoadingNewActivities,
                            message: viewModel.newActivitiesMessage
                        ) { activityId in
                            openActivityDetail(activityId: activityId)
                        }
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
        navigationPath = []

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
        case .searchCategory(let category):
            SearchCategoryActivityListView(
                category: category,
                authManager: authManager,
                activityDetailAction: { activityId in
                    openActivityDetail(activityId: activityId)
                }
            )
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
        // "전체"는 카테고리 필터를 적용하지 않는 의미이므로 서버 쿼리에서는 nil로 전달한다.
        guard let filter = MainCategoryFilter.samples.first(where: { $0.id == selectedCategoryID }),
              filter.id != "all" else {
            return nil
        }
        return filter.title
    }

    private var newActivitiesQueryID: String {
        "\(selectedCountryID)-\(selectedCategoryID)"
    }
}

private enum MainRoute: Hashable {
    case activityDetail(activityId: String)
    case chat(roomId: String, opponentNick: String)
    case searchCategory(SearchCategory)
}

#Preview {
    MainView(authManager: AuthManager())
}
