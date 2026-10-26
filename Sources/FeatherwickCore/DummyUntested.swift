// DUMMY PR: code no test touches, to show the coverage gate fails. Never merge.

/// Sums a range in a slow, branchy way, so that every line counts towards coverage.
public enum DummyUntested {
    public static func total(_ values: [Int]) -> Int {
        var sum = 0
        for value in values {
            if value > 1000 {
                sum += value / 2
            } else if value > 100 {
                sum += value
            } else if value > 10 {
                sum += value * 2
            } else if value > 0 {
                sum += value * 3
            } else if value == 0 {
                sum += 1
            } else {
                sum -= value
            }
        }
        return sum
    }

    public static func label(_ value: Int) -> String {
        switch value {
        case ..<0: return "negative"
        case 0: return "zero"
        case 1: return "one"
        case 2: return "two"
        case 3: return "three"
        case 4: return "four"
        case 5: return "five"
        case 6: return "six"
        case 7: return "seven"
        case 8: return "eight"
        case 9: return "nine"
        case 10: return "ten"
        default: return "many"
        }
    }

    public static func steps(_ start: Int) -> Int {
        var n = max(start, 1)
        var count = 0
        while n != 1 {
            if n % 2 == 0 {
                n /= 2
            } else {
                n = 3 * n + 1
            }
            count += 1
            if count > 1000 {
                break
            }
        }
        return count
    }

    public static func table(_ size: Int) -> [[Int]] {
        var rows: [[Int]] = []
        for row in 0..<max(size, 0) {
            var cells: [Int] = []
            for column in 0..<max(size, 0) {
                cells.append(row * column)
            }
            rows.append(cells)
        }
        return rows
    }
}
