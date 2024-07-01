const std = @import("std");
const net = std.net;
const os = std.os.linux;

const PF_INET = 2;
const SOCK_DGRAM = 2;

// li_vn_mode: u8,
// stratum: u8,
// poll: i8,
// precision: i8,
// root_delay: u32,
// root_dispersion: u32,
// reference_id: u32,
// reference_timestamp: u64,
// origin_timestamp: u64,
// receive_timestamp: u64,
// transmit_timestamp: u64,

const NtpPacket = extern struct { li_vn_mode: u8, stratum: u8, poll: u8, precision: u8, rootDelay: u32, rootDispersion: u32, refId: u32, refTm_s: u32, refTm_f: u32, origTm_s: u32, origTm_f: u32, rxTm_s: u32, rxTm_f: u32, txTm_s: u32, txTm_f: u32 };

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
