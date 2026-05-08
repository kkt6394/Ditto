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
    @State private var zoomingActivityId: String?
    @State private var zoomingImageRequest: URLRequest?
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
    @State private var presentedBannerWebView: BannerWebViewPresentation?
    @State private var isPresentingVideoFeed = false
    @State private var isPresentingSearch = false

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
            .sheet(item: $presentedBannerWebView) { presentation in
                BannerWebViewLauncher.makeWebView(for: presentation, authManager: authManager)
            }
            .fullScreenCover(isPresented: $isPresentingVideoFeed) {
                VideoFeedView(authManager: authManager)
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
                            destination: proxy[destAnchor]
                        ) {
                            keepStore.finishFlightAnimation(activityId: flightID)
                        }
                        .id(flightID)
                    }
                }
                .allowsHitTesting(false)
            }
            // 좋아요 카드 → 상세 hero zoom 오버레이. NavigationStack push 위에 그려져
            // 이미지가 그리드 위치에서 상단 hero 위치로 확대되는 트랜지션을 보여준다.
            .overlayPreferenceValue(LikesZoomAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    if let id = zoomingActivityId,
                       let pair = anchors[id],
                       let sourceAnchor = pair.source {
                        let sourceRect = proxy[sourceAnchor]
                        // detail의 hero anchor가 publish되면 그걸 destination으로 쓴다.
                        // detail이 아직 mount되지 않은 짧은 순간에는 fallback rect를 사용한다.
                        let destRect: CGRect = {
                            if let destAnchor = pair.destination {
                                return proxy[destAnchor]
                            }
                            return heroDestinationRect(in: proxy)
                        }()
                        LikesZoomOverlay(
                            activityId: id,
                            imageRequest: zoomingImageRequest,
                            source: sourceRect,
                            destination: destRect
                        )
                        .id(id)
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
        .environment(\.likesZoomActive, zoomingActivityId != nil)
        .onAppear {
            updateChatPresence()
            // 앱 종료 상태에서 푸시 탭으로 켜졌다면 PushNavigator에 이미 pending이 들어와 있다.
            handlePendingChatPushIfNeeded()
        }
        .onChange(of: selectedTabID) { _, _ in
            updateChatPresence()
        }
        .onChange(of: navigationPath.count) { _, _ in
            updateChatPresence()
        }
        .onChange(of: PushNavigator.shared.pendingChat) { _, _ in
            handlePendingChatPushIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        TabView(selection: $selectedTabID) {
            homeTab
                .tag(MainTab.home.rawValue)

            FeedView(
                viewModel: viewModel,
                searchAction: { isPresentingSearch = true },
                mediaAction: { media in
                    selectedMedia = media
                },
                detailAction: { post in
                    openPostDetail(for: post)
                },
                chatAction: { post in
                    startChat(with: post)
                }
            )
                .tag(MainTab.feed.rawValue)

            ChatListView(authManager: authManager) { roomId, opponentNick in
                navigationPath.append(MainRoute.chat(roomId: roomId, opponentNick: opponentNick))
            }
            .tag(MainTab.chat.rawValue)

            LikesView(
                isActive: selectedTabID == MainTab.likes.rawValue,
                activityDetailAction: { activityId in
                    openLikedActivityDetail(activityId: activityId)
                },
                startZoomTransition: { activity in
                    zoomingImageRequest = activity.imageRequest
                    zoomingActivityId = activity.id
                    // 안전 장치: zoom 애니메이션 종료 시간 후 무조건 정리해
                    // 이전 화면의 이미지가 detail 화면 위에 잔존하지 않도록 한다.
                    let id = activity.id
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(480))
                        if zoomingActivityId == id {
                            withAnimation(.easeOut(duration: 0.18)) {
                                zoomingActivityId = nil
                                zoomingImageRequest = nil
                            }
                        }
                    }
                }
            )
            .tag(MainTab.likes.rawValue)

            ProfileTabView(
                authManager: authManager,
                isActive: selectedTabID == MainTab.profile.rawValue,
                signOutMessage: signOutMessage,
                signOutAction: signOut,
                orderListAction: {
                    navigationPath.append(MainRoute.orderList)
                },
                composeActivityCardAction: {
                    navigationPath.append(MainRoute.activityCardCompose)
                },
                composeActivityAction: {
                    navigationPath.append(MainRoute.activityCompose(mode: .create))
                },
                myPostTapAction: { postId in
                    navigationPath.append(MainRoute.postDetail(postId: postId))
                },
                likedActivityTapAction: { activityId in
                    navigationPath.append(MainRoute.activityDetail(activityId: activityId))
                }
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
                        ) { banner in
                            presentedBannerWebView = BannerWebViewLauncher.presentation(for: banner)
                        }
                        .padding(.top, 16)

                        MainSectionTitleRow(title: "추천 액티비티")
                            .padding(.top, 28)

                        HomeRecommendationRow(
                            items: viewModel.homeRecommendations,
                            isLoading: viewModel.isLoadingHomeRecommendations,
                            message: viewModel.homeRecommendationsMessage
                        ) { activityId in
                            openActivityDetail(activityId: activityId)
                        }
                        .padding(.top, 12)

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
            .task {
                await viewModel.loadHomeRecommendations()
            }
        }
    }

    private var fixedHeader: some View {
        VStack(spacing: 0) {
            MainTopBar(
                openVideoFeedAction: { isPresentingVideoFeed = true },
                searchAction: { isPresentingSearch = true }
            )
                .padding(.horizontal, 20)
                .padding(.top, 12)

            CategoryIconGrid(
                items: MainCategoryFilter.samples,
                selectedID: $selectedCategoryID
            )
            .padding(.top, 12)
        }
    }
}

private extension MainView {
    // ActivityDetailView의 hero 이미지가 자리잡는 위치(상단 safe area + nav bar 44pt 아래, 너비 가득, 높이 360).
    // zoom 오버레이의 destination으로 사용한다.
    func heroDestinationRect(in proxy: GeometryProxy) -> CGRect {
        CGRect(
            x: 0,
            y: proxy.safeAreaInsets.top + 44,
            width: proxy.size.width,
            height: 360
        )
    }

    func updateChatPresence() {
        // 채팅 탭 루트(목록 화면) 노출 시점에만 무음 플래그를 켠다. 채팅방 진입 시엔 ChatRoomView가 activeRoomId를 갱신한다.
        let isOnChatListRoot = selectedTabID == MainTab.chat.rawValue && navigationPath.isEmpty
        ChatPresence.shared.isOnChatList = isOnChatListRoot
    }

    func handlePendingChatPushIfNeeded() {
        guard let pending = PushNavigator.shared.pendingChat else {
            return
        }

        // 진입에 필요한 최소 정보(상대 닉네임)를 페이로드 subtitle에서 받아온다.
        // subtitle이 비어있는 예외 페이로드는 조용히 소비한다 — 잘못된 진입을 만들지 않는다.
        guard let opponentNick = pending.opponentNickFallback, !opponentNick.isEmpty else {
            PushNavigator.shared.consume()
            return
        }

        // 채팅 탭으로 전환한 뒤 그 위에 채팅방을 push 한다. 이미 다른 화면이 쌓여 있으면 한 번에 교체한다.
        selectedTabID = MainTab.chat.rawValue
        navigationPath = [.chat(roomId: pending.roomId, opponentNick: opponentNick)]
        PushNavigator.shared.consume()
    }

    var shouldShowComposerButton: Bool {
        navigationPath.isEmpty && selectedTabID == MainTab.home.rawValue
    }

    // 카테고리 리스트 화면도 검색 탭의 연장으로 보고 탭바를 유지한다.
    var shouldShowTabBar: Bool {
        guard let last = navigationPath.last else {
            return true
        }

        if case .searchCategory = last {
            return true
        }

        return false
    }

    func makeComposerContext() -> PostComposeInitialContext {
        PostComposeInitialContext(
            country: selectedCountryName ?? MainCountryFilter.samples[0].name,
            category: selectedCategoryTitle ?? MainCategoryFilter.samples[0].title
        )
    }

    func reloadActivityPostsAfterCompose() async {
        await viewModel.loadActivityPosts(
            country: selectedCountryName,
            category: selectedCategoryTitle
        )
    }

    func signOut() {
        // 서버 로그아웃 → 로컬 토큰 삭제 순서. 서버 호출은 best-effort라 실패해도 로컬 정리는 진행된다.
        Task {
            await viewModel.performServerLogout()
            do {
                try authManager.signOut()
            } catch {
                signOutMessage = "로그아웃 처리에 실패했습니다."
            }
        }
    }

    func selectTab(_ item: MainTabItem) {
        navigationPath = []

        if selectedTabID == item.id {
            if MainTab(rawValue: item.id) == .feed {
                searchViewResetID = UUID()
            } else if MainTab(rawValue: item.id) == .home {
                homeScrollToTopTrigger.toggle()
            }
        }

        selectedTabID = item.id
    }

    func openPostDetail(for post: MainActivityPost) {
        navigationPath.append(MainRoute.postDetail(postId: post.id))
    }

    func openActivityDetail(activityId: String) {
        navigationPath.append(MainRoute.activityDetail(activityId: activityId))
    }

    // 좋아요 탭의 zoom 트랜지션과 함께 쓰는 진입 함수. push 슬라이드가 zoom과 겹치지 않도록 애니메이션을 끈다.
    func openLikedActivityDetail(activityId: String) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            navigationPath.append(MainRoute.activityDetail(activityId: activityId))
        }
    }

    func startChat(with post: MainActivityPost) {
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

    var selectedCountryName: String? {
        MainCountryFilter.samples.first { $0.id == selectedCountryID }?.name
    }

    var selectedCategoryTitle: String? {
        // "전체"는 카테고리 필터를 적용하지 않는 의미이므로 서버 쿼리에서는 nil로 전달한다.
        guard let filter = MainCategoryFilter.samples.first(where: { $0.id == selectedCategoryID }),
              filter.id != "all" else {
            return nil
        }
        return filter.title
    }

    var newActivitiesQueryID: String {
        "\(selectedCountryID)-\(selectedCategoryID)"
    }

    @ViewBuilder
    func destination(for route: MainRoute) -> some View {
        switch route {
        case .activityDetail(let activityId):
            ActivityDetailView(
                activityId: activityId,
                authManager: authManager,
                onStartChat: { roomId, opponentNick in
                    navigationPath.append(MainRoute.chat(roomId: roomId, opponentNick: opponentNick))
                },
                onStartEdit: { editableId in
                    navigationPath.append(MainRoute.activityCompose(mode: .edit(activityId: editableId)))
                }
            )
        case .postDetail(let postId):
            PostDetailView(postId: postId, authManager: authManager)
        case .chat(let roomId, let opponentNick):
            ChatRoomView(roomId: roomId, opponentNick: opponentNick, authManager: authManager)
        case .searchCategory(let category):
            SearchCategoryActivityListView(
                category: category,
                authManager: authManager
            ) { activityId in
                openActivityDetail(activityId: activityId)
            }
        case .orderList:
            OrderListView(authManager: authManager) { orderCode, activityId, reviewId, thumbnailPath in
                navigationPath.append(.receipt(
                    orderCode: orderCode,
                    activityId: activityId,
                    existingReviewId: reviewId,
                    thumbnailPath: thumbnailPath
                ))
            }
        case .receipt(let orderCode, let activityId, let existingReviewId, let thumbnailPath):
            ReceiptView(
                orderCode: orderCode,
                activityId: activityId,
                existingReviewId: existingReviewId,
                thumbnailPath: thumbnailPath,
                authManager: authManager
            )
        case .activityCompose(let mode):
            ActivityComposeView(mode: mode, authManager: authManager) {
                // 작성 후 후처리는 후속 커밋에서 — 일단 화면만 닫는다.
            }
        case .activityCardCompose:
            ActivityCardComposeSelectorView(authManager: authManager)
        }
    }
}

#Preview { MainView(authManager: AuthManager()) }
