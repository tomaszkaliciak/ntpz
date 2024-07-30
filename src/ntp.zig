const std = @import("std");
const testing = std.testing;

const U16_SECOND_FRACTION_IN_MS = 0.01525878;
const U32_SECOND_FRACTION_IN_MS = 0.00000023283064365386962890625;

const NTP_UNIX_OFFSET_IN_S = 2208988800;

pub const Packet = extern struct {
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

pub const ShortTimestamp = extern struct { seconds: u16 = 0, fraction: u16 = 0 };

pub const LongTimestamp = extern struct {
    seconds: u32 = 0,
    fraction: u32 = 0,

    pub fn subtract(self: LongTimestamp, other: LongTimestamp) LongTimestamp {
        var output = LongTimestamp{};
        const x: u32 = self.seconds - other.seconds;
        const y: u32 = self.fraction - other.fraction;
        output.seconds = x;
        output.fraction = y;
        return output;
    }
};

test "subtract" {
    const t_1 = LongTimestamp{ .seconds = 1234, .fraction = 12 };
    const t_2 = LongTimestamp{ .seconds = 1234, .fraction = 13 };
    const expected = LongTimestamp{ .seconds = 0, .fraction = 1 };

    try testing.expectEqual(t_1.subtract(t_2), expected);
}

pub fn toShortTimestamp(payload: u32) ShortTimestamp {
    var timestmap = ShortTimestamp{};
    timestmap.seconds = @intCast(payload >> 16);
    timestmap.fraction = @intCast(payload & 0xFFFF);
    return timestmap;
}

pub fn toLongTimestamp(payload: u64) LongTimestamp {
    var timestmap = LongTimestamp{};
    timestmap.seconds = @intCast(payload >> 32);
    timestmap.fraction = @intCast(payload & 0xFFFFFFFF);
    return timestmap;
}

pub fn parsePacket(payload: [48]u8) Packet {
    var packet = Packet{};
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
}

pub fn print(packet: Packet) void {
    std.debug.print("Received li_vn_mode {b}\n", .{packet.li_vn_mode});
    std.debug.print("Received stratum {}\n", .{packet.stratum});
    std.debug.print("Received pollInterval {}\n", .{packet.pollInterval});
    std.debug.print("Received precision {}\n", .{packet.precision});
    std.debug.print("Received rootDelay {b}\n", .{packet.rootDelay});
    std.debug.print("Received rootDispersion {}\n", .{packet.rootDispersion});
    std.debug.print("Received referenceId {}\n", .{packet.referenceId});
    std.debug.print("Received referenceTime {}\n", .{packet.receiveTime});
    const rootDelay = toShortTimestamp(packet.rootDelay);
    std.debug.print("Received rootDelay {}s {} ms\n", .{ rootDelay.seconds, u16SecondFranctionToMs(@floatFromInt(rootDelay.fraction)) });
    const rootDispersion = toShortTimestamp(packet.rootDispersion);
    std.debug.print("Received rootDispersion {}s {} ms\n", .{ rootDispersion.seconds, u16SecondFranctionToMs(@floatFromInt(rootDispersion.fraction)) });
    const referenceTime = toLongTimestamp(packet.referenceTime);
    std.debug.print("Received referenceTime {}s {} ms\n", .{ referenceTime.seconds, u32SecondFranctionToMs(@floatFromInt(referenceTime.fraction)) });
    const originTime = toLongTimestamp(packet.originTime);
    std.debug.print("Received originTime {}s {} ms\n", .{ originTime.seconds, u32SecondFranctionToMs(@floatFromInt(originTime.fraction)) });
    const receiveTime = toLongTimestamp(packet.receiveTime);
    std.debug.print("Received receiveTime {}s {} ms\n", .{ receiveTime.seconds, u32SecondFranctionToMs(@floatFromInt(receiveTime.fraction)) });
    const transmitTime = toLongTimestamp(packet.transmitTime);
    std.debug.print("Received transmitTime {}s {} ms\n", .{ transmitTime.seconds, u32SecondFranctionToMs(@floatFromInt(transmitTime.fraction)) });
}

fn u16SecondFranctionToMs(fraction: f32) f32 {
    return U16_SECOND_FRACTION_IN_MS * fraction;
}

fn u32SecondFranctionToMs(fraction: f32) f32 {
    return U32_SECOND_FRACTION_IN_MS * fraction;
}

pub fn toNtpTimestamp(unitTimeStampInNs: i128) u64 {
    const ntpTimeInSec: u64 = @as(u64, @intCast(@divFloor(unitTimeStampInNs, std.time.ns_per_s))) + NTP_UNIX_OFFSET_IN_S;
    const nsecReminder: u64 = @intCast(@rem(unitTimeStampInNs, std.time.ns_per_s));
    const fracBeforeMsg: u64 = @truncate((nsecReminder << 32) / std.time.ns_per_s);
    const ntpTimeStampBeforeMsg: u64 = ntpTimeInSec << 32 | fracBeforeMsg;
    return ntpTimeStampBeforeMsg;
}
