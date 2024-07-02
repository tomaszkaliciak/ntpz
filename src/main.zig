const std = @import("std");
const net = std.net;
const os = std.os.linux;

const PF_INET = 2;
const SOCK_DGRAM = 2;

const NTP_UNIX_OFFSET_IN_NS = 2208988800000000000;

const NtpPacket = extern struct { li_vn_mode: u8, stratum: u8, pollInterval: u8, precision: i8, rootDelay: u32, rootDispersion: u32, referenceId: u32, referenceTime: u64, originTime: u64, receiveTime: u64, transmitTime: u64 };

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const hostname = "0.pl.pool.ntp.org";
    const resolutionResult = try net.getAddressList(allocator, hostname, 123);
    defer resolutionResult.deinit();

    const addrs = resolutionResult.addrs;

    for (addrs) |addr| {
        std.debug.print("{}\n", .{addr});
    }

    const now: u64 = @intCast(std.time.nanoTimestamp());
    const ntpTimestamp: u64 = now + NTP_UNIX_OFFSET_IN_NS;

    const ntpClientPacket = NtpPacket{
        .li_vn_mode = 0b00_100_011, // LI (Leap Indicator) = 0 (no notif), VN (Version Number) = 4 (NTPv4), Mode = 3 (client mode)
        .stratum = 0,
        .pollInterval = 0,
        .precision = 0,
        .rootDelay = 0,
        .rootDispersion = 0,
        .referenceId = 0,
        .referenceTime = 0,
        .originTime = 0,
        .receiveTime = 0,
        .transmitTime = @byteSwap(ntpTimestamp),
    };

    const firstAddr = addrs[0].any;
    const firstAddrLen = addrs[0].getOsSockLen();

    var buffer = std.mem.zeroes([48]u8);
    const ntpPacketInBytes: [48]u8 = @bitCast(ntpClientPacket);
    std.mem.copyForwards(u8, &buffer, &ntpPacketInBytes);

    const sockfd: i32 = @intCast(os.socket(PF_INET, SOCK_DGRAM, 0));
    _ = os.sendto(sockfd, &buffer, 48, 0, &firstAddr, firstAddrLen);
}
