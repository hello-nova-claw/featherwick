/// An enum whose cases are ranked in the order they are declared: the first case is the lowest.
///
/// Swift synthesises `Comparable` only for enums without raw values. These enums keep their String
/// raw values (saves use them), so they get the order from `allCases` instead.
public protocol CaseOrdered: CaseIterable, Comparable {}

extension CaseOrdered {
    public static func < (a: Self, b: Self) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}
