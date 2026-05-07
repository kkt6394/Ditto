//
//  ActivityReportPDFRenderer.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// 활동 리포트 PDF 렌더러.
// 표지 → 요약 통계 → 본문 카드 리스트(TextKit wrap-around) → 마무리 페이지 순으로 그린다.
struct ActivityReportPDFRenderer {
    let snapshot: ActivityReportSnapshot

    func render(to fileURL: URL) throws {
        let metadata: [String: Any] = [
            kCGPDFContextTitle as String: "Ditto 활동 리포트 · \(snapshot.scope.displayLabel)",
            kCGPDFContextAuthor as String: snapshot.userDisplayName,
            kCGPDFContextCreator as String: "Ditto"
        ]
        let renderer = PDFRenderer(pageSize: PDFPaper.a4Size, metadata: metadata)
        try renderer.render(to: fileURL) { ctx in
            drawCoverPage(ctx)
            ctx.newPage()
            drawSummaryPage(ctx)
            drawOrderListPages(ctx)
            ctx.newPage()
            drawClosingPage(ctx)
        }
    }

    // MARK: - 1. 표지

    private func drawCoverPage(_ ctx: PDFRenderContext) {
        let rect = ctx.contentRect

        let title = NSAttributedString(
            string: "내 액티비티 리포트",
            attributes: [
                .font: PDFAttributedStringBuilder.paperlogy(size: 36),
                .foregroundColor: PDFPalette.textPrimary
            ]
        )
        title.draw(at: CGPoint(x: rect.minX, y: rect.minY + 80))

        let subtitle = NSAttributedString(
            string: "\(snapshot.userDisplayName)님의 \(snapshot.scope.displayLabel) 기록",
            attributes: [
                .font: PDFAttributedStringBuilder.font(.semibold, size: 16),
                .foregroundColor: PDFPalette.textSecondary
            ]
        )
        subtitle.draw(at: CGPoint(x: rect.minX, y: rect.minY + 130))

        // 표지 우하단의 손글씨 메모 영역.
        // PaperKit 캔버스에서 캡쳐된 이미지가 그대로 들어간다.
        if let overlay = snapshot.markupOverlay {
            let overlaySize = CGSize(width: 220, height: 160)
            let overlayRect = CGRect(
                x: rect.maxX - overlaySize.width,
                y: rect.maxY - overlaySize.height,
                width: overlaySize.width,
                height: overlaySize.height
            )
            overlay.draw(in: overlayRect, blendMode: .normal, alpha: 1)
        }

        drawFooter(ctx, label: "표지 · Ditto")
    }

    // MARK: - 2. 요약 통계

    private func drawSummaryPage(_ ctx: PDFRenderContext) {
        let rect = ctx.contentRect

        drawSectionHeader(title: "한눈에 보는 활동", origin: CGPoint(x: rect.minX, y: rect.minY))

        let cardOriginY = rect.minY + 56
        let cardSize = CGSize(width: (rect.width - 16) / 2, height: 84)
        let cards: [(String, String)] = [
            ("총 활동", "\(snapshot.stats.totalCount)건"),
            ("총 지출", priceText(snapshot.stats.totalSpentKRW)),
            ("첫 액티비티", snapshot.stats.firstPaidAt.map(formattedDate) ?? "-"),
            ("최근 액티비티", snapshot.stats.lastPaidAt.map(formattedDate) ?? "-")
        ]
        for (index, card) in cards.enumerated() {
            let column = index % 2
            let row = index / 2
            let origin = CGPoint(
                x: rect.minX + CGFloat(column) * (cardSize.width + 16),
                y: cardOriginY + CGFloat(row) * (cardSize.height + 16)
            )
            drawStatCard(label: card.0, value: card.1, origin: origin, size: cardSize)
        }

        let categoryOriginY = cardOriginY + cardSize.height * 2 + 32 + 16
        drawSectionHeader(title: "카테고리 분포", origin: CGPoint(x: rect.minX, y: categoryOriginY))
        drawCategoryBars(
            origin: CGPoint(x: rect.minX, y: categoryOriginY + 32),
            availableWidth: rect.width
        )

        drawFooter(ctx, label: "요약 · Ditto")
    }

    private func drawStatCard(label: String, value: String, origin: CGPoint, size: CGSize) {
        let rect = CGRect(origin: origin, size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        PDFPalette.surface.setFill()
        path.fill()
        PDFPalette.border.setStroke()
        path.lineWidth = 1
        path.stroke()

        let labelText = NSAttributedString(
            string: label,
            attributes: [
                .font: PDFAttributedStringBuilder.font(.semibold, size: 12),
                .foregroundColor: PDFPalette.textSecondary
            ]
        )
        labelText.draw(at: CGPoint(x: rect.minX + 14, y: rect.minY + 14))

        let valueText = NSAttributedString(
            string: value,
            attributes: [
                .font: PDFAttributedStringBuilder.font(.bold, size: 20),
                .foregroundColor: PDFPalette.textPrimary
            ]
        )
        valueText.draw(at: CGPoint(x: rect.minX + 14, y: rect.minY + 38))
    }

    private func drawCategoryBars(origin: CGPoint, availableWidth: CGFloat) {
        let counts = snapshot.stats.categoryCounts
        guard let maxCount = counts.map(\.count).max(), maxCount > 0 else { return }

        let rowHeight: CGFloat = 22
        let labelWidth: CGFloat = 96
        let countWidth: CGFloat = 36
        let barAreaWidth = availableWidth - labelWidth - countWidth - 12

        for (index, item) in counts.enumerated() {
            let rowY = origin.y + CGFloat(index) * (rowHeight + 8)

            let labelText = NSAttributedString(
                string: item.name,
                attributes: [
                    .font: PDFAttributedStringBuilder.font(.medium, size: 12),
                    .foregroundColor: PDFPalette.textPrimary
                ]
            )
            labelText.draw(at: CGPoint(x: origin.x, y: rowY + 4))

            let ratio = CGFloat(item.count) / CGFloat(maxCount)
            let barRect = CGRect(
                x: origin.x + labelWidth,
                y: rowY + 6,
                width: max(barAreaWidth * ratio, 4),
                height: 12
            )
            PDFPalette.primaryBlue.setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: 4).fill()

            let countText = NSAttributedString(
                string: "\(item.count)",
                attributes: [
                    .font: PDFAttributedStringBuilder.font(.semibold, size: 12),
                    .foregroundColor: PDFPalette.textSecondary
                ]
            )
            countText.draw(at: CGPoint(x: origin.x + labelWidth + barAreaWidth + 12, y: rowY + 4))
        }
    }

    // MARK: - 4. 마무리

    private func drawClosingPage(_ ctx: PDFRenderContext) {
        let rect = ctx.contentRect

        let watermark = NSAttributedString(
            string: "Ditto",
            attributes: [
                .font: PDFAttributedStringBuilder.paperlogy(size: 64),
                .foregroundColor: PDFPalette.primaryBlue
            ]
        )
        let size = watermark.size()
        watermark.draw(at: CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        ))

        let line = NSAttributedString(
            string: "오늘도 새로운 한 줄을 적어보세요.",
            attributes: [
                .font: PDFAttributedStringBuilder.font(.medium, size: 14),
                .foregroundColor: PDFPalette.textSecondary
            ]
        )
        line.draw(at: CGPoint(x: rect.midX - line.size().width / 2, y: rect.midY + size.height / 2 + 16))

        drawFooter(ctx, label: "마침")
    }
}

// MARK: - 본문 카드 (TextKit wrap-around)
//
// 페이지당 한 액티비티를 큼직한 사진 + 사진 주변을 따라 흐르는 텍스트로 보여준다.
// `NSTextContainer.exclusionPaths`가 사진 사각형을 피해 가도록 layout manager를 구성한다.
private extension ActivityReportPDFRenderer {
    func drawOrderListPages(_ ctx: PDFRenderContext) {
        guard !snapshot.orders.isEmpty else { return }
        for order in snapshot.orders {
            ctx.newPage()
            drawActivityCardPage(order: order, in: ctx)
        }
    }

    func drawActivityCardPage(order: OrderReviewResponseDTO, in ctx: PDFRenderContext) {
        let rect = ctx.contentRect

        let title = NSAttributedString(
            string: order.activity.title ?? "이름 없는 액티비티",
            attributes: [
                .font: PDFAttributedStringBuilder.paperlogy(size: 24),
                .foregroundColor: PDFPalette.textPrimary
            ]
        )
        title.draw(at: CGPoint(x: rect.minX, y: rect.minY))

        let bodyOrigin = CGPoint(x: rect.minX, y: rect.minY + 56)
        let bodySize = CGSize(width: rect.width, height: rect.maxY - bodyOrigin.y - 24)

        let imageSide: CGFloat = 220
        let imageRect = CGRect(x: bodyOrigin.x, y: bodyOrigin.y, width: imageSide, height: imageSide)
        drawActivityImage(order: order, in: imageRect, ctx: ctx)

        let body = makeActivityBody(order: order)
        drawWrappedText(body, origin: bodyOrigin, size: bodySize, around: imageRect)

        drawFooter(ctx, label: "내 액티비티 · Ditto")
    }

    func drawActivityImage(
        order: OrderReviewResponseDTO,
        in rect: CGRect,
        ctx: PDFRenderContext
    ) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)

        if let image = snapshot.thumbnails[order.orderId] {
            // aspect-fill로 사진을 둥근 사각형 안에 잘라 넣는다.
            ctx.cgContext.saveGState()
            path.addClip()
            let imageSize = image.size
            let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
            let scaled = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let drawRect = CGRect(
                x: rect.midX - scaled.width / 2,
                y: rect.midY - scaled.height / 2,
                width: scaled.width,
                height: scaled.height
            )
            image.draw(in: drawRect)
            ctx.cgContext.restoreGState()
        } else {
            // 이미지 다운로드 실패한 경우 placeholder.
            PDFPalette.primaryBlueSoft.setFill()
            path.fill()
            let placeholder = NSAttributedString(
                string: "사진을 불러올 수 없어요",
                attributes: [
                    .font: PDFAttributedStringBuilder.font(.medium, size: 12),
                    .foregroundColor: PDFPalette.textMuted
                ]
            )
            let size = placeholder.size()
            placeholder.draw(at: CGPoint(
                x: rect.midX - size.width / 2,
                y: rect.midY - size.height / 2
            ))
        }
    }

    func makeActivityBody(order: OrderReviewResponseDTO) -> NSAttributedString {
        let combined = NSMutableAttributedString()
        appendActivityMeta(into: combined, order: order)
        appendActivitySummary(into: combined, order: order)
        return combined
    }

    func appendActivityMeta(
        into combined: NSMutableAttributedString,
        order: OrderReviewResponseDTO
    ) {
        combined.append(PDFAttributedStringBuilder.paragraph(
            order.reservationItemName,
            font: PDFAttributedStringBuilder.font(.bold, size: 14),
            color: PDFPalette.textPrimary,
            spacingAfter: 6
        ))

        if let category = order.activity.category {
            combined.append(PDFAttributedStringBuilder.paragraph(
                "카테고리 \(category)",
                font: PDFAttributedStringBuilder.font(.medium, size: 12),
                color: PDFPalette.textSecondary,
                spacingAfter: 4
            ))
        }

        combined.append(PDFAttributedStringBuilder.paragraph(
            "일정 \(order.reservationItemTime)",
            font: PDFAttributedStringBuilder.font(.regular, size: 12),
            color: PDFPalette.textSecondary,
            spacingAfter: 4
        ))

        combined.append(PDFAttributedStringBuilder.paragraph(
            "참가 인원 \(order.participantCount)명",
            font: PDFAttributedStringBuilder.font(.regular, size: 12),
            color: PDFPalette.textSecondary,
            spacingAfter: 4
        ))

        combined.append(PDFAttributedStringBuilder.paragraph(
            "결제 \(priceText(order.totalPrice))",
            font: PDFAttributedStringBuilder.font(.semibold, size: 12),
            color: PDFPalette.textPrimary,
            spacingAfter: 4
        ))

        combined.append(PDFAttributedStringBuilder.paragraph(
            "결제일 \(formattedDateString(order.paidAt))",
            font: PDFAttributedStringBuilder.font(.regular, size: 11),
            color: PDFPalette.textMuted,
            spacingAfter: 12
        ))
    }

    func appendActivitySummary(
        into combined: NSMutableAttributedString,
        order: OrderReviewResponseDTO
    ) {
        if let rating = order.review?.rating {
            let filled = max(0, min(5, Int(rating.rounded())))
            let stars = String(repeating: "★", count: filled)
                + String(repeating: "☆", count: 5 - filled)
            combined.append(PDFAttributedStringBuilder.paragraph(
                "후기 별점 \(stars)",
                font: PDFAttributedStringBuilder.font(.medium, size: 12),
                color: PDFPalette.textPrimary,
                spacingAfter: 8
            ))
        }

        // 사진 옆에서 시작해 아래로 흘러 페이지 폭 전체를 채우는 짧은 회고 문장.
        let summary = "이 액티비티에 \(order.participantCount)명이 함께했어요. "
            + "\(formattedDateString(order.paidAt)) \(order.reservationItemName) 일정으로 진행했고, "
            + "결제 금액은 \(priceText(order.totalPrice))였습니다. "
            + "사진 한 장이 그날의 분위기를 다시 떠올리게 합니다."
        combined.append(PDFAttributedStringBuilder.paragraph(
            summary,
            font: PDFAttributedStringBuilder.font(.regular, size: 12),
            color: PDFPalette.textSecondary,
            lineHeightMultiple: 1.5,
            spacingAfter: 0
        ))
    }

    func drawWrappedText(
        _ text: NSAttributedString,
        origin: CGPoint,
        size: CGSize,
        around imageRect: CGRect
    ) {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        let container = NSTextContainer(size: size)
        container.lineFragmentPadding = 0

        // exclusion path는 컨테이너 좌표계(origin 기준)에서 정의한다.
        // 사진 사각형보다 8pt 여유를 둬 글자가 사진에 바로 붙지 않게 한다.
        let local = CGRect(
            x: imageRect.minX - origin.x,
            y: imageRect.minY - origin.y,
            width: imageRect.width,
            height: imageRect.height
        ).insetBy(dx: -8, dy: -8)
        container.exclusionPaths = [UIBezierPath(rect: local)]
        layout.addTextContainer(container)

        layout.drawGlyphs(
            forGlyphRange: layout.glyphRange(for: container),
            at: origin
        )
    }
}

// MARK: - 페이지 헤더/푸터/포맷터 헬퍼
//
// 모든 페이지가 같은 톤의 헤더/푸터를 갖도록 헬퍼만 별도 extension으로 둔다.
private extension ActivityReportPDFRenderer {
    func drawSectionHeader(title: String, origin: CGPoint) {
        let header = NSAttributedString(
            string: title,
            attributes: [
                .font: PDFAttributedStringBuilder.font(.bold, size: 18),
                .foregroundColor: PDFPalette.textPrimary
            ]
        )
        header.draw(at: origin)

        let underline = UIBezierPath()
        underline.move(to: CGPoint(x: origin.x, y: origin.y + 28))
        underline.addLine(to: CGPoint(x: origin.x + 36, y: origin.y + 28))
        PDFPalette.primaryBlue.setStroke()
        underline.lineWidth = 2
        underline.stroke()
    }

    func drawFooter(_ ctx: PDFRenderContext, label: String) {
        let pageString = "\(ctx.pageIndex + 1)"
        let leftText = NSAttributedString(
            string: label,
            attributes: [
                .font: PDFAttributedStringBuilder.font(.regular, size: 10),
                .foregroundColor: PDFPalette.textMuted
            ]
        )
        let rightText = NSAttributedString(
            string: "\(pageString) · \(formattedDate(snapshot.generatedAt))",
            attributes: [
                .font: PDFAttributedStringBuilder.font(.regular, size: 10),
                .foregroundColor: PDFPalette.textMuted
            ]
        )
        let baseline = ctx.pageSize.height - PDFPaper.margin.bottom + 24
        leftText.draw(at: CGPoint(x: PDFPaper.margin.left, y: baseline))
        let rightSize = rightText.size()
        rightText.draw(at: CGPoint(
            x: ctx.pageSize.width - PDFPaper.margin.right - rightSize.width,
            y: baseline
        ))
    }

    func priceText(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(number)원"
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    func formattedDateString(_ raw: String) -> String {
        // 서버가 ISO8601일 때만 사람이 읽기 쉬운 형식으로 바꾸고, 실패하면 원본 그대로.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return formattedDate(date) }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: raw) { return formattedDate(date) }
        return raw
    }
}
