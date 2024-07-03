const std = @import("std");
const net = std.net;
const os = std.os.linux;

const PF_INET = 2;
const SOCK_DGRAM = 2;

const NTP_UNIX_OFFSET_IN_S = 2208988800;

const NtpPacket = extern struct {
    li_vn_mode: u8 = 0,
    stratum: u8 = 0,
    pollInterval: u8 = 0,
    precision: i8 = 0,
    rootDelay: u32 = 0,
    rootDispersion: u32 = 0,
    referenceId: u32 = 0,
    referenceTime: u64 = 0,
    originTime: u64 = 0,
    receiveTime: u64 = 0,
    transmitTime: u64 = 0,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const hostname = "0.pl.pool.ntp.org";
    const resolutionResult = try net.getAddressList(allocator, hostname, 123);
    defer resolutionResult.deinit();

    const addrs = resolutionResult.addrs;

    if (addrs.len < 1) {
        return;
    }

    for (addrs) |addr| {
        std.debug.print("{}\n", .{addr});
    }

    const now: u64 = @intCast(std.time.timestamp()); // unix time in [s]

    const ntpTimeSeconds: u64 = now + NTP_UNIX_OFFSET_IN_S;

    // NTPTime.fraction = 1 ==> 1/(2^32)s == 0.2ns
    // let's dont think about it for now
    const ntpTimeFraction: u64 = 0;

    const ntpTimeStamp: u64 = ntpTimeSeconds << 32 | ntpTimeFraction;

    const ntpClientPacket = NtpPacket{
        .li_vn_mode = 0b00_100_011, // LI (Leap Indicator) = 0 (no notif), VN (Version Number) = 4 (NTPv4), Mode = 3 (client mode)
        .transmitTime = @byteSwap(ntpTimeStamp),
    };

    const ntpPacketInBytes: [48]u8 = @bitCast(ntpClientPacket);
    var buffer = std.mem.zeroes([48]u8);
    std.mem.copyForwards(u8, &buffer, &ntpPacketInBytes);

    const sockfd: i32 = @intCast(os.socket(PF_INET, SOCK_DGRAM, 0));

    const addr = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 1996);
    _ = os.bind(sockfd, &addr.any, addr.getOsSockLen());

    const firstAddr = addrs[0].any;
    const firstAddrLen = addrs[0].getOsSockLen();

    _ = os.sendto(sockfd, &buffer, 48, 0, &firstAddr, firstAddrLen);

    var buffer2: [48]u8 = undefined;
    var srcAddr: net.Address = undefined;
    var srcAddrLen: os.socklen_t = @sizeOf(net.Address);

    const recv_result = os.recvfrom(sockfd, &buffer2, 48, 0, &srcAddr.any, &srcAddrLen);

    std.debug.print("Received {}: {x}\n", .{
        recv_result,
        buffer2[0..recv_result],
    });
}
