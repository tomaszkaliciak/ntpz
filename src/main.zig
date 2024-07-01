const std = @import("std");
const net = std.net;
const os = std.os.linux;

const PF_INET = 2;
const SOCK_DGRAM = 2;

const NTP_UNIX_OFFSET_IN_NS = 2208988800000000000;

// .li_vn_mode = 0x1B,  // LI = 0, VN = 4, Mode = 3 (client)
// LI (Leap Indicator) = 0 (no notif)
// VN (Version Number) = 4 (NTPv4)
// Mode = 3 (client mode)

const NtpPacket = extern struct { li_vn_mode: u8, stratum: u8, poll: u8, precision: i8, rootDelay: u32, rootDispersion: u32, referenceId: u32, referenceTime: u64, originTime: u64, receiveTime: u64, transmitTime: u64 };

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const hostname = "0.pl.pool.ntp.org";
    const resolutionResult = try net.getAddressList(allocator, hostname, 123);
    defer resolutionResult.deinit();

    const addrs = resolutionResult.addrs;

    for (addrs) |addr| {
        std.debug.print("{}\n", .{addr});
    }

    const sockfd: i32 = @intCast(os.socket(PF_INET, SOCK_DGRAM, 0));
    const buffer = std.mem.zeroes([1024]u8);

    const firstAddr = addrs[0].any;
    const firstAddrLen = addrs[0].getOsSockLen();

    _ = os.sendto(sockfd, &buffer, 1024, 0, &firstAddr, firstAddrLen);
    // linux.sendto(sockfd, buffer, 1024, 0, (struct sockaddr*)&serverAddr, sizeof(serverAddr));

}
