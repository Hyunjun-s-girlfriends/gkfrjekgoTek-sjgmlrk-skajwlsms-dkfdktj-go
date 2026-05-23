import Foundation

#if canImport(Darwin)
import Darwin
#endif

enum LocalNetworkInfo {
    static func bridgeURL(port: Int = 3000) -> String {
        guard let address = primaryIPv4Address() else {
            return "http://맥북IP:\(port)"
        }
        return "http://\(address):\(port)"
    }

    private static func primaryIPv4Address() -> String? {
        #if canImport(Darwin)
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = current?.pointee {
            defer { current = interface.ifa_next }
            guard
                interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                let name = String(validatingUTF8: interface.ifa_name),
                name == "en0" || name == "en1"
            else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                return String(cString: hostname)
            }
        }
        #endif
        return nil
    }
}
