//
//  WebVTTParser.swift
//  Ditto
//
//  Created by Codex on 5/6/26.
//

import Foundation

// 외부 .vtt 파일에서 시간 큐만 추출하는 미니 파서.
// AVPlayer가 외부 자막을 직접 인식하지 못해, WebVTT를 우리가 파싱해서 SwiftUI 오버레이로 직접 그린다.
// positioning, region, styling cue 같은 고급 기능은 의도적으로 무시하고 (시작, 끝, 텍스트)만 본다.
struct WebVTTCue: Equatable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum WebVTTParser {
    static func parse(_ content: String) -> [WebVTTCue] {
        // CRLF / CR 줄바꿈을 LF로 정규화한다.
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var cues: [WebVTTCue] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            // 시간 라인은 "-->"를 포함한다. 식별자(라벨) 라인은 그 위에 올 수도 있고, 큐 식별자 없이도 유효하다.
            if line.contains("-->"), let range = parseTimeRange(line) {
                var textLines: [String] = []
                var cursor = index + 1
                while cursor < lines.count {
                    let textLine = lines[cursor]
                    // 빈 줄이 큐 블록 끝을 의미한다.
                    if textLine.trimmingCharacters(in: .whitespaces).isEmpty { break }
                    textLines.append(textLine)
                    cursor += 1
                }
                let text = textLines.joined(separator: "\n")
                cues.append(WebVTTCue(start: range.start, end: range.end, text: text))
                index = cursor
                continue
            }
            index += 1
        }
        return cues
    }

    private static func parseTimeRange(_ line: String) -> (start: TimeInterval, end: TimeInterval)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count >= 2 else { return nil }
        let leftToken = parts[0].trimmingCharacters(in: .whitespaces)
        // 우측은 setting cue(예: align:start position:50%)가 붙을 수 있으니 첫 토큰만 사용한다.
        let rightToken = parts[1]
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
            .first ?? ""
        guard
            let start = parseTimestamp(leftToken),
            let end = parseTimestamp(rightToken)
        else { return nil }
        return (start, end)
    }

    private static func parseTimestamp(_ token: String) -> TimeInterval? {
        // HH:MM:SS.mmm 또는 MM:SS.mmm 형식만 지원한다.
        let segments = token.components(separatedBy: ":")
        guard segments.count == 2 || segments.count == 3 else { return nil }
        var hours: Double = 0
        var minutes: Double = 0
        let secondsToken: String
        if segments.count == 3 {
            guard let parsedHours = Double(segments[0]),
                  let parsedMinutes = Double(segments[1]) else { return nil }
            hours = parsedHours
            minutes = parsedMinutes
            secondsToken = segments[2]
        } else {
            guard let parsedMinutes = Double(segments[0]) else { return nil }
            minutes = parsedMinutes
            secondsToken = segments[1]
        }
        let secondsParts = secondsToken.components(separatedBy: ".")
        guard let seconds = Double(secondsParts[0]) else { return nil }
        let milliseconds: Double
        if secondsParts.count >= 2, let parsedMillis = Double(secondsParts[1]) {
            milliseconds = parsedMillis / 1000.0
        } else {
            milliseconds = 0
        }
        return hours * 3600 + minutes * 60 + seconds + milliseconds
    }
}
