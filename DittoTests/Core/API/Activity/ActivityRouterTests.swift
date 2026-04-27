//
//  ActivityRouterTests.swift
//  DittoTests
//
//  Created by Codex on 4/25/26.
//

@testable import Ditto
import Foundation
import Testing

struct ActivityRouterTests {
    @Test func listRouterBuildsExpectedQueryItems() {
        let router = ActivityRouter.list(
            ActivityListQuery(
                country: "대한민국",
                category: "투어",
                limit: 20,
                next: "cursor-1"
            )
        )

        #expect(router.method == .get)
        #expect(router.path == "v1/activities")
        #expect(router.requiresAuthentication)
        #expect(router.queryItems == [
            URLQueryItem(name: "country", value: "대한민국"),
            URLQueryItem(name: "category", value: "투어"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "next", value: "cursor-1")
        ])
    }

    @Test func newRouterBuildsExpectedQueryItems() {
        let router = ActivityRouter.new(
            ActivityPreviewQuery(
                country: "대한민국",
                category: "투어"
            )
        )

        #expect(router.method == .get)
        #expect(router.path == "v1/activities/new")
        #expect(router.requiresAuthentication)
        #expect(router.queryItems == [
            URLQueryItem(name: "country", value: "대한민국"),
            URLQueryItem(name: "category", value: "투어")
        ])
    }

    @Test func uploadFilesRouterUsesMultipartInsteadOfJSONBody() {
        let file = MultipartFile(
            filename: "sample.jpg",
            mimeType: "image/jpeg",
            data: Data("sample".utf8)
        )
        let router = ActivityRouter.uploadFiles(ActivityFileUploadRequestDTO(files: [file]))

        #expect(router.method == .post)
        #expect(router.path == "v1/activities/files")
        #expect(router.body == nil)
        #expect(router.multipartFormData != nil)
    }
}
