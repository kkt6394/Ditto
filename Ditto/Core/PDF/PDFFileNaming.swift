//
//  PDFFileNaming.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation

// PDF 파일 이름 규칙을 한 곳에 모아둬 공유 URL과 파일명이 어긋나지 않게 한다.
enum PDFFileNaming {
    static func activityReport(date: Date = .now) -> String {
        "Ditto_활동리포트_\(dateString(date)).pdf"
    }

    static func receipt(orderCode: String) -> String {
        "Ditto_영수증_\(sanitize(orderCode)).pdf"
    }

    // 파일 시스템에서 문제될 수 있는 문자만 _로 치환. 한글은 그대로 둔다.
    private static func sanitize(_ raw: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return String(raw.unicodeScalars.map { unsafe.contains($0) ? "_" : Character($0) })
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // 모든 PDF가 같은 임시 폴더 아래 생성되도록 통일.
    static func temporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DittoPDF", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
