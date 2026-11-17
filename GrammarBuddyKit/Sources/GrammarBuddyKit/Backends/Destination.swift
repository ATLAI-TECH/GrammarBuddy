// Destination.swift
// Where the text goes (design §7.4). The badge says only what the app actually knows.

import Foundation

public enum Destination: Equatable, Sendable {
    case thisMac, localNetwork, myDevice, internet

    /// Classify by host. (The design asks for resolved IPs before each request; hostnames cover the prototype.)
    public static func classify(_ url: String, myDevices: Set<String> = []) -> Destination {
        // built-in model and Apple Intelligence run inside this Mac
        if url.hasPrefix("builtin:") || url.hasPrefix("apple:") { return .thisMac }
        guard let host = URL(string: url)?.host?.lowercased() else { return .internet }
        if myDevices.contains(host) { return .myDevice }
        let p = host.split(separator: ".").compactMap { Int($0) }
        let isIPv4 = p.count == 4 && host.split(separator: ".").count == 4
        if host == "localhost" || host == "::1" || (isIPv4 && p[0] == 127) { return .thisMac }   // not "127.example.com" (G5-09)
        let ipv6 = host.contains(":")
        if ipv6 {
            // link-local fe80::/10 and unique-local fc00::/7; everything else is a public address
            return host.hasPrefix("fe80:") || host.hasPrefix("fd") || host.hasPrefix("fc") ? .localNetwork : .internet
        }
        if host.hasSuffix(".local") || !host.contains(".") { return .localNetwork }
        // Tailscale names and 100.64/10 count as "my device" only when the user marks them (§7.4, G5-09)
        if isIPv4 {
            if p[0] == 10 || (p[0] == 192 && p[1] == 168) || (p[0] == 172 && (16...31).contains(p[1])) || (p[0] == 169 && p[1] == 254) { return .localNetwork }
        }
        return .internet
    }

    public var leavesMac: Bool { self != .thisMac }
}
