const std = @import("std");
const chrono = @import("chrono");

pub fn main() !void {
    var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_allocator.deinit();
    const gpa = gpa_allocator.allocator();

    var tzdb = try chrono.tz.DataBase.init(gpa);
    defer tzdb.deinit();

    const timezone = try tzdb.getLocalTimeZone();

    const timestamp_utc = std.time.timestamp();
    const local_offset = timezone.offsetAtTimestamp(timestamp_utc) orelse {
        std.debug.print("Could not convert the current time to local time.", .{});
        return error.ConversionFailed;
    };
    const timestamp_local = timestamp_utc + local_offset;

    const designation = timezone.designationAtTimestamp(timestamp_utc);

    const date = chrono.date.YearMonthDay.fromDaysSinceUnixEpoch(@intCast(@divFloor(timestamp_local, std.time.s_per_day)));
    const time = chrono.Time{ .secs = @intCast(@mod(timestamp_local, std.time.s_per_day)), .frac = 0 };

    std.debug.print("The current date is {}, and the time is {} in the {?s} timezone\n", .{ date, time, designation });

    if (timezone.identifier()) |identifier| {
        std.debug.print("The IANA time zone identifier = \"{}\"\n", .{std.zig.fmtEscapes(identifier.string)});
    } else {
        std.debug.print("The IANA time zone identifier is unknown\n", .{});
    }
}
