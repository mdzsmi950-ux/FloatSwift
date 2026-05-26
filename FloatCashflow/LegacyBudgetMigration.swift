import Foundation

enum LegacyBudgetMigration {
    static let storageKey = "float_budget_v1"

    static func budgetFromContainerFiles() -> FloatBudget? {
        let fileManager = FileManager.default
        let roots = [
            fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true,
                      (values.fileSize ?? 0) < 5_000_000 else {
                    continue
                }

                guard let data = try? Data(contentsOf: url) else { continue }
                if let budget = budgetFromRawData(data) {
                    return budget
                }
            }
        }

        return nil
    }

    static func budgetFromLocalStorageValue(_ value: String?) -> FloatBudget? {
        guard let value, !value.isEmpty else { return nil }
        return decodeBudget(from: value)
    }

    private static func budgetFromRawData(_ data: Data) -> FloatBudget? {
        let strings = [
            String(data: data, encoding: .utf8),
            String(data: data, encoding: .ascii),
            String(data: data, encoding: .isoLatin1)
        ].compactMap { $0 }

        for string in strings where string.contains(storageKey) || string.contains("\"version\"") {
            if let budget = budgetFromEscapedLocalStorageString(in: string) {
                return budget
            }

            if let budget = budgetFromEmbeddedJSON(in: string) {
                return budget
            }
        }

        return nil
    }

    private static func budgetFromEscapedLocalStorageString(in string: String) -> FloatBudget? {
        let pattern = #""float_budget_v1"\s*[:,]\s*"((?:\\.|[^"\\])*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)

        for match in regex.matches(in: string, range: range) {
            guard let matchRange = Range(match.range(at: 1), in: string) else { continue }
            let escaped = String(string[matchRange])
            let wrapped = "\"\(escaped)\""
            guard let data = wrapped.data(using: .utf8),
                  let decodedString = try? JSONDecoder().decode(String.self, from: data),
                  let budget = decodeBudget(from: decodedString) else {
                continue
            }
            return budget
        }

        return nil
    }

    private static func budgetFromEmbeddedJSON(in string: String) -> FloatBudget? {
        let anchors = [
            #"{"version":1,"activeAccountId""#,
            #"{"version":1, "activeAccountId""#,
            #"{"version": 1,"activeAccountId""#,
            #"{"version": 1, "activeAccountId""#
        ]

        for anchor in anchors {
            var searchStart = string.startIndex
            while let range = string.range(of: anchor, range: searchStart..<string.endIndex) {
                if let json = balancedJSONObject(in: string, from: range.lowerBound),
                   let budget = decodeBudget(from: json) {
                    return budget
                }

                searchStart = range.upperBound
            }
        }

        return nil
    }

    private static func balancedJSONObject(in string: String, from start: String.Index) -> String? {
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = start

        while index < string.endIndex {
            let character = string[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        let end = string.index(after: index)
                        return String(string[start..<end])
                    }
                }
            }

            index = string.index(after: index)
        }

        return nil
    }

    private static func decodeBudget(from string: String) -> FloatBudget? {
        guard let data = string.data(using: .utf8),
              let budget = try? JSONDecoder().decode(FloatBudget.self, from: data),
              budget.version == 1,
              !budget.accounts.isEmpty else {
            return nil
        }

        return budget
    }
}
