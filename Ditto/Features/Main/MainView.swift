//
//  MainView.swift
//  Ditto
//
//  Created by 김기태 on 4/24/26.
//

import SwiftUI

struct MainView: View {
    @State private var selectedCountryID = MainCountryFilter.samples[0].id
    @State private var selectedCategoryID = MainCategoryFilter.samples[0].id

    var body: some View {
        ZStack(alignment: .bottom) {
            MainScreenPalette.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
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

                    MainSectionTitleRow(
                        title: "NEW 액티비티",
                        trailingTitle: "View All"
                    )
                    .padding(.top, 20)

                    NewActivityCarousel(items: MainNewActivity.samples)
                        .padding(.top, 12)

                    ActivityPostsSection(posts: MainActivityPost.samples)
                        .padding(.top, 24)
                }
                .padding(.bottom, 110)
            }

            MainBottomTabBar(items: MainTabItem.samples)
        }
    }
}

#Preview {
    MainView()
}
