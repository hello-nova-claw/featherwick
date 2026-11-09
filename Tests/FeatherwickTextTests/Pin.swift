/// A fingerprint of many lines of words (64-bit FNV-1a over the UTF-8 bytes). A pin test compares it
/// with the fingerprint from before the words moved into the String Catalog (#58): any changed byte
/// changes it. The test's exact lines show where a change is.
func pin(_ lines: [String?]) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in lines.map({ $0 ?? "<nil>" }).joined(separator: "\n").utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01b3
    }
    return String(hash, radix: 16)
}
