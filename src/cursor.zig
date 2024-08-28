const std = @import("std");

pub const cmd = "\x1B[";

pub fn writer() std.fs.File.Writer {
    return std.io.getStdOut().writer();
}

pub fn clear() !void {
    try writer().writeAll(cmd ++ "2J");
}

pub fn save() !void {
    try writer().writeAll(cmd ++ "s");
}

pub fn restore() !void {
    try writer().writeAll(cmd ++ "u");
}

pub fn set(comptime row: u8, comptime column: u8) !void {
    try writer().writeAll(cmd ++ std.fmt.comptimePrint("{d};{d}H", .{ row + 1, column + 1 }));
}

pub fn set_column(comptime column: u8) !void {
    try writer().writeAll(cmd ++ std.fmt.comptimePrint("{d}G", .{column}));
}

pub fn up(comptime off: u8) !void {
    try writer().writeAll(cmd ++ std.fmt.comptimePrint("{d}A", .{off}));
}

pub fn down(comptime off: u8) !void {
    try writer().writeAll(cmd ++ std.fmt.comptimePrint("{d}B", .{off}));
}

pub fn right(comptime off: u8) !void {
    try writer().writeAll(cmd ++ std.fmt.comptimePrint("{d}C", .{off}));
}

pub fn left(comptime off: u8) !void {
    try writer().writeAll(cmd ++ std.fmt.comptimePrint("{d}D", .{off}));
}
