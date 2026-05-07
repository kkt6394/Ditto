//
//  ActivityMemoryCanvasView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI
import UIKit

// 캔버스 metrics + 종이 배경. 디자인 객체 21개는 internal struct로 별도 노출되어
// NodeRenderView가 ActivityCardCanvasNode.content에 따라 호출한다.
// 각 디자인 view는 자체 .offset/.rotationEffect를 갖지 않으며, 외부에서 .position/.rotationEffect/.scaleEffect로 배치된다.
struct ActivityMemoryCanvasView: View {
    static let canvasSize = CGSize(width: 595, height: 842)

    var body: some View {
        ActivityMemoryPaper()
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
            .background(MemoryPalette.paper)
    }
}

// MARK: - 데이터 / 색 / 폰트 토큰

struct ActivityMemorySnapshot {
    let activityTitle: String
    let category: String?
    let totalPrice: Int
    let paidAt: String
    let participantCount: Int
    let scheduleLines: [String]
    let activityImage: UIImage?
    let signatureOverlay: UIImage?
}

extension ActivityMemorySnapshot {
    var formattedDateMultiline: String {
        let parsed = parsePaidAt()
        let dateString = parsed.map { date -> String in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM dd, yyyy"
            return formatter.string(from: date).uppercased()
        } ?? paidAt
        let dayTime = parsed.map { date -> String in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE HH:mm"
            return formatter.string(from: date).uppercased()
        } ?? ""
        return dayTime.isEmpty ? dateString : "\(dateString)\n\(dayTime)"
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: totalPrice)) ?? "\(totalPrice)"
        return "KRW \(number)"
    }

    private func parsePaidAt() -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: paidAt) { return date }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: paidAt)
    }
}

enum MemoryPalette {
    static let paper = Color(red: 1.00, green: 0.976, blue: 0.925)
    static let yellow = Color(red: 1.00, green: 0.941, blue: 0.651)
    static let mint = Color(red: 0.737, green: 0.933, blue: 0.910)
    static let pink = Color(red: 0.969, green: 0.773, blue: 0.749)
    static let red = Color(red: 1.00, green: 0.42, blue: 0.42)
    static let ink = Color(red: 0.082, green: 0.067, blue: 0.055)
    static let teal = Color(red: 0.176, green: 0.549, blue: 0.514)
}

enum MemoryFont {
    static func serifItalic(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .serif).italic()
    }
    static func sansHeavy(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy)
    }
    static func sansBlack(size: CGFloat) -> Font {
        .system(size: size, weight: .black)
    }
    static func sansMedium(size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }
}

// MARK: - 베이스

struct ActivityMemoryPaper: View {
    var body: some View {
        Rectangle().fill(MemoryPalette.paper)
    }
}

// MARK: - 헤더 (brand / sub)

struct ActivityMemoryBrand: View {
    var body: some View {
        Text("Ditto")
            .font(MemoryFont.serifItalic(size: 62))
            .foregroundStyle(MemoryPalette.ink)
    }
}

struct ActivityMemorySub: View {
    var body: some View {
        Text("activity journal")
            .font(MemoryFont.sansBlack(size: 12))
            .foregroundStyle(MemoryPalette.ink)
    }
}

// MARK: - sticky note 4종

struct ActivityMemoryDateBox: View {
    let snapshot: ActivityMemorySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATE").font(MemoryFont.sansBlack(size: 13))
            Text(snapshot.formattedDateMultiline)
                .font(MemoryFont.sansHeavy(size: 18))
                .lineSpacing(2)
        }
        .foregroundStyle(MemoryPalette.ink)
        .padding(14)
        .frame(width: 150, alignment: .leading)
        .background(MemoryPalette.yellow)
        .overlay(Rectangle().stroke(MemoryPalette.ink, lineWidth: 3))
    }
}

struct ActivityMemoryGuestsBox: View {
    let snapshot: ActivityMemorySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("GUESTS").font(MemoryFont.sansBlack(size: 13))
            Text("\(snapshot.participantCount)").font(MemoryFont.sansBlack(size: 38))
        }
        .foregroundStyle(MemoryPalette.ink)
        .padding(12)
        .frame(width: 122, alignment: .leading)
        .background(MemoryPalette.pink)
        .overlay(Rectangle().stroke(MemoryPalette.ink, lineWidth: 3))
    }
}

struct ActivityMemoryScheduleBox: View {
    let snapshot: ActivityMemorySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE").font(MemoryFont.sansBlack(size: 15))
            Text(snapshot.scheduleLines.joined(separator: "\n"))
                .font(MemoryFont.sansHeavy(size: 14))
                .lineSpacing(0)
        }
        .foregroundStyle(MemoryPalette.ink)
        .padding(16)
        .frame(width: 214, alignment: .leading)
        .background(MemoryPalette.pink)
        .overlay(Rectangle().stroke(MemoryPalette.ink, lineWidth: 3))
    }
}

struct ActivityMemoryTotalBox: View {
    let snapshot: ActivityMemorySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOTAL").font(MemoryFont.sansBlack(size: 15))
            Text(snapshot.formattedPrice).font(MemoryFont.sansBlack(size: 27))
        }
        .foregroundStyle(MemoryPalette.ink)
        .padding(15)
        .frame(width: 190, alignment: .leading)
        .background(MemoryPalette.yellow)
        .overlay(Rectangle().stroke(MemoryPalette.ink, lineWidth: 3))
    }
}

// MARK: - 메인 사진 / 라벨 / 도장 / 인용

struct ActivityMemoryHeroImage: View {
    let image: UIImage?
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                MemoryPalette.mint
            }
        }
        .frame(width: 312, height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(MemoryPalette.ink, lineWidth: 4))
        .shadow(color: MemoryPalette.ink.opacity(0.95), radius: 0, x: 9, y: 10)
    }
}

struct ActivityMemoryMainLabel: View {
    let snapshot: ActivityMemorySnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ACTIVITY NAME").font(MemoryFont.sansBlack(size: 11))
            // 폰트는 그대로 두고 객체 자체가 텍스트 길이에 맞춰 자동으로 늘어난다.
            Text(snapshot.activityTitle)
                .font(MemoryFont.serifItalic(size: 30))
                .lineLimit(1)
        }
        .foregroundStyle(MemoryPalette.ink)
        .padding(.horizontal, 16).padding(.vertical, 10)
        // fixedSize(horizontal: true)로 콘텐츠 너비를 그대로 유지 → 이름이 길수록 박스도 길어진다.
        .fixedSize(horizontal: true, vertical: false)
        .background(MemoryPalette.mint)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(MemoryPalette.ink, lineWidth: 3))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct ActivityMemoryQuote: View {
    var body: some View {
        Text("saved this moment!")
            .font(MemoryFont.serifItalic(size: 18))
            .foregroundStyle(MemoryPalette.ink)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(MemoryPalette.ink, lineWidth: 3))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ActivityMemoryStamp: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("DONE").font(MemoryFont.sansBlack(size: 21))
            Text("ACTIVITY").font(MemoryFont.sansBlack(size: 11))
        }
        .foregroundStyle(MemoryPalette.ink)
        .frame(width: 112, height: 112)
        .background(MemoryPalette.mint)
        .overlay(Circle().stroke(MemoryPalette.ink, lineWidth: 4))
        .clipShape(Circle())
    }
}

// MARK: - 데코

struct ActivityMemoryHeartDeco: View {
    var body: some View {
        ZStack {
            Circle().fill(MemoryPalette.red)
                .overlay(Circle().stroke(MemoryPalette.ink, lineWidth: 4))
                .frame(width: 54, height: 54)
            Text("♥").font(MemoryFont.sansBlack(size: 24)).foregroundStyle(.white)
        }
        .frame(width: 54, height: 54)
    }
}

struct ActivityMemoryArrowDeco: View {
    let name: String
    let size: CGSize
    let weight: Font.Weight

    init(name: String, size: CGSize, weight: Font.Weight = .heavy) {
        self.name = name
        self.size = size
        self.weight = weight
    }

    var body: some View {
        Image(systemName: name)
            .font(.system(size: min(size.width, size.height) * 0.7, weight: weight))
            .foregroundStyle(MemoryPalette.ink)
            .frame(width: size.width, height: size.height)
    }
}

struct ActivityMemoryClipDeco: View {
    var body: some View {
        Image(systemName: "paperclip")
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(MemoryPalette.ink)
    }
}

struct ActivityMemoryStarDeco: View {
    let symbol: String
    let color: Color

    var body: some View {
        Text(symbol)
            .font(MemoryFont.sansBlack(size: 32))
            .foregroundStyle(color)
    }
}

struct ActivityMemoryBottomTitle: View {
    var body: some View {
        Text("MY ACTIVITY PAGE")
            .font(MemoryFont.sansBlack(size: 34))
            .foregroundStyle(MemoryPalette.ink)
    }
}

struct ActivityMemoryUnderline: View {
    var body: some View {
        Capsule()
            .fill(Color(red: 0.475, green: 0.847, blue: 0.937))
            .frame(width: 302, height: 8)
    }
}
