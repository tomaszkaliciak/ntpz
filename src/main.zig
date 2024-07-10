const std = @import("std");
const net = std.net;
const os = std.os.linux;

const c = @cImport({
    @cInclude("time.h");
});

const PF_INET = 2;
const SOCK_DGRAM = 2;

const NTP_UNIX_OFFSET_IN_S = 2208988800;

const U16_SECOND_FRACTION_IN_MS = 0.01525878;
const U32_SECOND_FRACTION_IN_MS = 0.00000023283064365386962890625;

const NtpShortFormat = extern struct { seconds: u16 = 0, fraction: u16 = 0 };

const NtpTimestampFormat = extern struct { seconds: u32 = 0, fraction: u32 = 0 };

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
    var buffer_out = std.mem.zeroes([48]u8);
    std.mem.copyForwards(u8, &buffer_out, &ntpPacketInBytes);

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

    const packetFromServer = parsePacket(buffer_in);

    std.debug.print("Received li_vn_mode {b}\n", .{packetFromServer.li_vn_mode});
    std.debug.print("Received stratum {}\n", .{packetFromServer.stratum});
    std.debug.print("Received pollInterval {}\n", .{packetFromServer.pollInterval});
    std.debug.print("Received precision {}\n", .{packetFromServer.precision});
    std.debug.print("Received rootDelay {b}\n", .{packetFromServer.rootDelay});
    std.debug.print("Received rootDispersion {}\n", .{packetFromServer.rootDispersion});
    std.debug.print("Received referenceId {}\n", .{packetFromServer.referenceId});
    std.debug.print("Received referenceTime {}\n", .{packetFromServer.receiveTime});

    const rootDelay = parseNtpShort(packetFromServer.rootDelay);
    std.debug.print("Received rootDelay {}s {} ms\n", .{ rootDelay.seconds, u16SecondFranctionToMs(@floatFromInt(rootDelay.fraction)) });

    const rootDispersion = parseNtpShort(packetFromServer.rootDispersion);
    std.debug.print("Received rootDispersion {}s {} ms\n", .{ rootDispersion.seconds, u16SecondFranctionToMs(@floatFromInt(rootDispersion.fraction)) });

    const referenceTime = parseNtpTimestamp(packetFromServer.referenceTime);
    std.debug.print("Received referenceTime {}s {} ms\n", .{ referenceTime.seconds, u32SecondFranctionToMs(@floatFromInt(referenceTime.fraction)) });

    const originTime = parseNtpTimestamp(packetFromServer.originTime);
    std.debug.print("Received originTime {}s {} ms\n", .{ originTime.seconds, u32SecondFranctionToMs(@floatFromInt(originTime.fraction)) });

    const receiveTime = parseNtpTimestamp(packetFromServer.receiveTime);
    std.debug.print("Received receiveTime {}s {} ms\n", .{ receiveTime.seconds, u32SecondFranctionToMs(@floatFromInt(receiveTime.fraction)) });

    const transmitTime = parseNtpTimestamp(packetFromServer.transmitTime);
    std.debug.print("Received transmitTime {}s {} ms\n", .{ transmitTime.seconds, u32SecondFranctionToMs(@floatFromInt(transmitTime.fraction)) });
}

fn u16SecondFranctionToMs(fraction: f32) f32 {
    return U16_SECOND_FRACTION_IN_MS * fraction;
}

fn u32SecondFranctionToMs(fraction: f32) f32 {
    return U32_SECOND_FRACTION_IN_MS * fraction;
}

fn parseNtpShort(payload: u32) NtpShortFormat {
    var ntpTime = NtpShortFormat{};
    ntpTime.seconds = @intCast(payload >> 16);
    ntpTime.fraction = @intCast(payload & 0xFFFF);
    return ntpTime;
}

fn parseNtpTimestamp(payload: u64) NtpTimestampFormat {
    var ntpTime = NtpTimestampFormat{};
    ntpTime.seconds = @intCast(payload >> 32);
    ntpTime.fraction = @intCast(payload & 0xFFFFFFFF);
    return ntpTime;
}

fn parsePacket(payload: [48]u8) NtpPacket {
    var packet = NtpPacket{};
    packet.li_vn_mode = payload[0];
    packet.stratum = payload[1];
    packet.pollInterval = payload[2]; // OK - 2 = 8s? check format
    packet.precision = @bitCast(payload[3]); // -24 , check format
    packet.rootDelay = std.mem.readInt(u32, payload[4..8], std.builtin.Endian.big);
    packet.rootDispersion = std.mem.readInt(u32, payload[8..12], std.builtin.Endian.big);
    packet.referenceId = std.mem.readInt(u32, payload[12..16], std.builtin.Endian.big);
    packet.referenceTime = std.mem.readInt(u64, payload[16..24], std.builtin.Endian.big);
    packet.originTime = std.mem.readInt(u64, payload[24..32], std.builtin.Endian.big);
    packet.receiveTime = std.mem.readInt(u64, payload[32..40], std.builtin.Endian.big);
    packet.transmitTime = std.mem.readInt(u64, payload[40..], std.builtin.Endian.big);
    return packet;

    // 0011 1010
}

// 0000 0010 0010 0011
