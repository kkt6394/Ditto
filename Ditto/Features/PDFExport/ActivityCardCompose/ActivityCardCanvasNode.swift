//
//  ActivityCardCanvasNode.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// 캔버스에 그려지는 모든 노드의 통합 모델 — 디자인 객체·텍스트·이미지가 같은 데이터로.
// position은 캔버스 좌표계(595x842) 기준 center, rotation/scale은 그 center 기준 transform.
// nodes 배열의 끝에 가까울수록 z-order 위. 사용자가 노드를 탭/드래그하면 끝으로 옮겨 자동으로 위에 뜨게 한다.
struct ActivityCardCanvasNode: Identifiable, Equatable {
    let id: UUID
    var content: NodeContent
    var position: CGPoint
    var rotation: Double
    var scale: CGFloat

    enum NodeContent: Equatable {
        case text(String)
        case image(UIImage)
        // 디자인 객체는 어느 액티비티의 데이터를 쓸지 orderIndex로 지정.
        case design(kind: DesignKind, orderIndex: Int)
        // TextKit `exclusionPaths`로 사진 옆에 텍스트가 흐르는 회고 메모 카드.
        case memoCard(text: String, orderIndex: Int)

        static func == (lhs: NodeContent, rhs: NodeContent) -> Bool {
            switch (lhs, rhs) {
            case (.text(let lhsText), .text(let rhsText)):
                return lhsText == rhsText
            case (.image(let lhsImage), .image(let rhsImage)):
                return lhsImage === rhsImage
            case (.design(let lhsKind, let lhsIndex), .design(let rhsKind, let rhsIndex)):
                return lhsKind == rhsKind && lhsIndex == rhsIndex
            case (.memoCard(let lhsText, let lhsIndex), .memoCard(let rhsText, let rhsIndex)):
                return lhsText == rhsText && lhsIndex == rhsIndex
            default:
                return false
            }
        }
    }

    init(
        id: UUID = UUID(),
        content: NodeContent,
        position: CGPoint,
        rotation: Double = 0,
        scale: CGFloat = 1
    ) {
        self.id = id
        self.content = content
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}

// Pencil POy3e 디자인의 정적 객체 21종. ViewModel.bootstrap에서 노드로 자동 생성된다.
enum DesignKind: String, Hashable, CaseIterable {
    case brand
    case sub
    case heroImage
    case mainLabel
    case dateBox
    case guestsBox
    case scheduleBox
    case totalBox
    case quote
    case stamp
    case heart
    case clip
    case star1
    case star2
    case hashSign
    case bottomTitle
    case underline
    case arrow1
    case arrow2
    case arrow3
}

extension DesignKind {
    // Pencil 디자인의 top-left + size 기준으로 환산한 SwiftUI .position center.
    var defaultPosition: CGPoint {
        switch self {
        case .brand: return CGPoint(x: 130, y: 60)
        case .sub: return CGPoint(x: 425, y: 50)
        case .heroImage: return CGPoint(x: 298, y: 316)
        case .mainLabel: return CGPoint(x: 299, y: 429)
        case .dateBox: return CGPoint(x: 127, y: 181)
        case .guestsBox: return CGPoint(x: 487, y: 172)
        case .scheduleBox: return CGPoint(x: 161, y: 617)
        case .totalBox: return CGPoint(x: 439, y: 600)
        case .quote: return CGPoint(x: 166, y: 491)
        case .stamp: return CGPoint(x: 432, y: 508)
        case .heart: return CGPoint(x: 277, y: 153)
        case .clip: return CGPoint(x: 528, y: 110)
        case .star1: return CGPoint(x: 510, y: 240)
        case .star2: return CGPoint(x: 110, y: 264)
        case .hashSign: return CGPoint(x: 484, y: 350)
        case .bottomTitle: return CGPoint(x: 190, y: 750)
        case .underline: return CGPoint(x: 199, y: 798)
        case .arrow1: return CGPoint(x: 267, y: 172)
        case .arrow2: return CGPoint(x: 359, y: 499)
        case .arrow3: return CGPoint(x: 289, y: 705)
        }
    }

    var defaultRotation: Double {
        switch self {
        case .brand: return -3
        case .sub: return 2
        case .mainLabel: return -2
        case .dateBox: return -2
        case .guestsBox: return 3
        case .scheduleBox: return -1
        case .totalBox: return 2
        case .quote: return 4
        case .stamp: return -8
        case .clip: return 18
        case .star1: return 12
        case .star2: return -8
        case .hashSign: return 8
        case .bottomTitle: return -2
        default: return 0
        }
    }
}
