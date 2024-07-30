const std = @import("std");
const net = std.net;
const os = std.os.linux;
const ntp = @import("ntp.zig");

const c = @cImport({
    @cInclude("time.h");
});

const PF_INET = 2;
const SOCK_DGRAM = 2;

//timedatectl timesync-status

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

    const ntpTimestampBeforeMsg = ntp.toNtpTimestamp(std.time.nanoTimestamp());
    const ntpClientPacket = ntp.Packet{
        .li_vn_mode = 0b00_100_011, // LI (Leap Indicator) = 0 (no notif), VN (Version Number) = 4 (NTPv4), Mode = 3 (client mode)
        .transmitTime = @byteSwap(ntpTimestampBeforeMsg),
    };

    const PacketInBytes: [48]u8 = @bitCast(ntpClientPacket);
    var buffer_out = std.mem.zeroes([48]u8);
    std.mem.copyForwards(u8, &buffer_out, &PacketInBytes);

    const sockfd: i32 = @intCast(os.socket(PF_INET, SOCK_DGRAM, 0));

    const firstAddr = addrs[0].any;
    const firstAddrLen = addrs[0].getOsSockLen();

    _ = os.sendto(sockfd, &buffer_out, 48, 0, &firstAddr, firstAddrLen);

    var buffer_in: [48]u8 = undefined;
    var srcAddr: net.Address = undefined;
    var srcAddrLen: os.socklen_t = @sizeOf(net.Address);

    const recv_result = os.recvfrom(sockfd, &buffer_in, 48, 0, &srcAddr.any, &srcAddrLen);

    std.debug.print("Received {}: {x}\n", .{
        recv_result,
        buffer_in[0..recv_result],
    });

    const packetFromServer: ntp.Packet = ntp.parsePacket(buffer_in);
    ntp.print(packetFromServer);

    // offset = [(T2 - T1) + (T3 - T4)] / 2
    // delay = (T4 - T1) - (T3 - T2)

    // roundtrip delay = T(ABA) = (T4-T1) - (T3-T2)
    // result.delay = ;
}
// fn printTimestamp(cTime: c.time_t) void {
//     var buf: [200]u8 = undefined;
//     const tm = c.gmtime(&cTime);
//     _ = c.strftime(&buf, 200, "%a %b %e %Y %H:%M:%S %Z", tm);
//     std.debug.print("Server received msg at {s} \n", .{buf});
// }
