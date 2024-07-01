const std = @import("std");
const net = std.net;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const hostname = "0.pl.pool.ntp.org";
    const resolutionResult = try net.getAddressList(allocator, hostname, 123);

    for (resolutionResult.addrs) |addr| {
        std.debug.print("{}\n", .{addr});
    }
}
