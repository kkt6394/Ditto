//
//  ReceiptPDFRenderer.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// 단건 액티비티 추억 PDF.
// 1페이지에 큰 액티비티 이미지 + 제목 + 메타 + PaperKit 사인 영역을 보여준다.
struct ReceiptPDFRenderer {
    let snapshot: ReceiptPDFSnapshot

    func render(to fileURL: URL) throws {
        let metadata: [String: Any] = [
            kCGPDFContextTitle as String: "Ditto · \(snapshot.activityTitle)",
            kCGPDFContextCreator as String: "Ditto"
        ]
        let renderer = PDFRenderer(pageSize: PDFPaper.a4Size, metadata: metadata)
        try renderer.render(to: fileURL) { ctx in
            let imageBottomY = drawHeroImage(ctx)
            let titleBottomY = drawTitle(ctx, originY: imageBottomY + 28)
            drawMetaText(ctx, originY: titleBottomY + 16)
            drawSignature(ctx)
            drawFooter(ctx)
        }
    }

    @discardableResult
    private func drawHeroImage(_ ctx: PDFRenderContext) -> CGFloat {
        let rect = ctx.contentRect
        let heroHeight: CGFloat = 360
        let heroRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: heroHeight
        )
        let path = UIBezierPath(roundedRect: heroRect, cornerRadius: 16)

        if let image = snapshot.activityImage {
            ctx.cgContext.saveGState()
            path.addClip()
            // aspect-fill: 비율을 유지하며 영역을 가득 채우고 밖으로 잘린다.
            let imageSize = image.size
            let scale = max(heroRect.width / imageSize.width, heroRect.height / imageSize.height)
            let scaled = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let drawRect = CGRect(
                x: heroRect.midX - scaled.width / 2,
                y: heroRect.midY - scaled.height / 2,
                width: scaled.width,
                height: scaled.height
            )
            image.draw(in: drawRect)
            ctx.cgContext.restoreGState()
        } else {
            PDFPalette.primaryBlueSoft.setFill()
            path.fill()
            let placeholder = NSAttributedString(
                string: "사진을 불러올 수 없어요",
                attributes: [
                    .font: PDFAttributedStringBuilder.font(.medium, size: 14),
                    .foregroundColor: PDFPalette.textMuted
                ]
            )
            let size = placeholder.size()
            placeholder.draw(at: CGPoint(
                x: heroRect.midX - size.width / 2,
                y: heroRect.midY - size.height / 2
            ))
        }
        return heroRect.maxY
    }

    private func drawTitle(_ ctx: PDFRenderContext, originY: CGFloat) -> CGFloat {
        let rect = ctx.contentRect
        let title = NSAttributedString(
            string: snapshot.activityTitle,
            attributes: [
                .font: PDFAttributedStringBuilder.paperlogy(size: 30),
                .foregroundColor: PDFPalette.textPrimary
            ]
        )
        let titleSize = title.size()
        title.draw(at: CGPoint(x: rect.minX, y: originY))
        return originY + titleSize.height
    }

    private func drawMetaText(_ ctx: PDFRenderContext, originY: CGFloat) {
        let rect = ctx.contentRect
        var rows: [(String, String)] = []
        if let category = snapshot.category {
            rows.append(("카테고리", category))
        }
        rows.append(("결제 금액", priceText(snapshot.totalPrice)))
        rows.append(("결제일", formattedDateString(snapshot.paidAt)))

        let rowHeight: CGFloat = 26
        let labelWidth: CGFloat = 96

        for (index, row) in rows.enumerated() {
            let rowY = originY + CGFloat(index) * rowHeight

            let label = NSAttributedString(
                string: row.0,
                attributes: [
                    .font: PDFAttributedStringBuilder.font(.semibold, size: 13),
                    .foregroundColor: PDFPalette.textSecondary
                ]
            )
            label.draw(at: CGPoint(x: rect.minX, y: rowY))

            let value = NSAttributedString(
                string: row.1,
                attributes: [
                    .font: PDFAttributedStringBuilder.font(.regular, size: 13),
                    .foregroundColor: PDFPalette.textPrimary
                ]
            )
            value.draw(at: CGPoint(x: rect.minX + labelWidth, y: rowY))
        }
    }

    private func drawSignature(_ ctx: PDFRenderContext) {
        let rect = ctx.contentRect
        let signatureSize = CGSize(width: 220, height: 110)
        let signatureRect = CGRect(
            x: rect.maxX - signatureSize.width,
            y: rect.maxY - signatureSize.height,
            width: signatureSize.width,
            height: signatureSize.height
        )

        let label = NSAttributedString(
            string: "추억 메모",
            attributes: [
                .font: PDFAttributedStringBuilder.font(.medium, size: 11),
                .foregroundColor: PDFPalette.textMuted
            ]
        )
        label.draw(at: CGPoint(x: signatureRect.minX, y: signatureRect.minY - 20))

        let box = UIBezierPath(roundedRect: signatureRect, cornerRadius: 10)
        PDFPalette.border.setStroke()
        box.lineWidth = 1
        box.stroke()

        if let overlay = snapshot.signatureOverlay {
            overlay.draw(in: signatureRect.insetBy(dx: 8, dy: 8), blendMode: .normal, alpha: 1)
        }
    }

    private func drawFooter(_ ctx: PDFRenderContext) {
        let line = NSAttributedString(
            string: "Ditto · 함께한 한 장의 사진과 한 줄의 메모.",
            attributes: [
                .font: PDFAttributedStringBuilder.font(.regular, size: 10),
                .foregroundColor: PDFPalette.textMuted
            ]
        )
        line.draw(at: CGPoint(
            x: PDFPaper.margin.left,
            y: ctx.pageSize.height - PDFPaper.margin.bottom + 24
        ))
    }

    private func priceText(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(number)원"
    }

    private func formattedDateString(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return formatDate(date) }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: raw) { return formatDate(date) }
        return raw
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}
