const std = @import("std");
const Cursor = @import("cursor.zig");
const tis = @import("tis.zig");

const Input0Data = [_]i16{};
var Input0Idx: usize = 0;
const Input1Data = [_]i16{ 44, 78, 88, 95, 65, 63, 41, 26, 87, 75, 21, 21, 62, 43, 26, 45, 13, 26, 30, 33, 34, 24, 39, 55, 54, 52, 67, 18, 77, 41, 31, 68, 28, 19, 97, 76, 27, 55, 89 };
var Input1Idx: usize = 0;
const Input2Data = [_]i16{ 93, 60, 92, 68, 56, 30, 90, 65, 94, 92, 62, 35, 63, 57, 45, 40, 81, 11, 35, 20, 85, 29, 86, 84, 36, 18, 33, 87, 87, 54, 82, 69, 31, 18, 79, 24, 34, 67, 74 };
var Input2Idx: usize = 0;
const Input3Data = [_]i16{};
var Input3Idx: usize = 0;

var OutputData: [4][256]i16 = .{.{0} ** 256} ** 4;
var OutputIdx: [4]usize = .{0} ** 4;

var ExpectedOutput0 = [_]i16{};
var ExpectedOutput1 = [_]i16{ -49, 18, -4, 27, 9, 33, -49, -39, -7, -17 };
var ExpectedOutput2 = [_]i16{ 49, -18, 4, -27, -9, -33, 49, 39, 7, 17 };
var ExpectedOutput3 = [_]i16{};

fn input_0() ?i16 {
    if (Input0Idx >= Input0Data.len) {
        return null;
    }
    const val = Input0Data[Input0Idx];
    Input0Idx += 1;
    return val;
}

fn input_1() ?i16 {
    if (Input1Idx >= Input1Data.len) {
        return null;
    }
    const val = Input1Data[Input1Idx];
    Input1Idx += 1;
    return val;
}

fn input_2() ?i16 {
    if (Input2Idx >= Input2Data.len) {
        return null;
    }
    const val = Input2Data[Input2Idx];
    Input2Idx += 1;
    return val;
}

fn input_3() ?i16 {
    if (Input3Idx >= Input3Data.len) {
        return null;
    }
    const val = Input3Data[Input3Idx];
    Input3Idx += 1;
    return val;
}

fn output_0(val: i16) void {
    OutputData[0][OutputIdx[0]] = val;
    OutputIdx[0] += 1;
}

fn output_1(val: i16) void {
    OutputData[1][OutputIdx[1]] = val;
    OutputIdx[1] += 1;
}

fn output_2(val: i16) void {
    OutputData[2][OutputIdx[2]] = val;
    OutputIdx[2] += 1;
}

fn output_3(val: i16) void {
    OutputData[3][OutputIdx[3]] = val;
    OutputIdx[3] += 1;
}

pub fn main() !void {
    var tis100: tis.TIS100 = .{};

    tis100.inputs[0] = &input_0;
    tis100.outputs[0] = &output_0;

    tis100.inputs[1] = &input_1;
    tis100.outputs[1] = &output_1;

    tis100.inputs[2] = &input_2;
    tis100.outputs[2] = &output_2;

    tis100.inputs[3] = &input_3;
    tis100.outputs[3] = &output_3;

    tis100.nodes[1][0].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .RIGHT } });

    tis100.nodes[1][2].append(.{ .MOV = .{ .src = .{ .Register = .RIGHT }, .dst = .ACC } });
    tis100.nodes[1][2].append(.NEG);
    tis100.nodes[1][2].append(.{ .MOV = .{ .src = .{ .Register = .ACC }, .dst = .DOWN } });

    tis100.nodes[2][0].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .ACC } });
    tis100.nodes[2][0].append(.{ .SUB = .{ .src = .{ .Register = .LEFT } } });
    tis100.nodes[2][0].append(.{ .MOV = .{ .src = .{ .Register = .ACC }, .dst = .DOWN } });

    tis100.nodes[2][1].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .DOWN } });

    tis100.nodes[2][2].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .ACC } });
    tis100.nodes[2][2].append(.{ .MOV = .{ .src = .{ .Register = .ACC }, .dst = .LEFT } });
    tis100.nodes[2][2].append(.{ .MOV = .{ .src = .{ .Register = .ACC }, .dst = .DOWN } });

    try tis100.print();

    const stdin = std.io.getStdIn().reader();
    var buf: [256]u8 = undefined;

    while (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        if (std.mem.eql(u8, user_input, "q") or std.mem.eql(u8, user_input, "q\r")) break;

        tis100.tick();
        try tis100.print();

        comptime var col: u8 = 2 + 34 * 4;

        if (comptime Input0Data.len > 0) {
            try Cursor.set(0, col);
            try Cursor.writer().writeAll("In 0");
            try Cursor.set(2, col);

            for (0..@min(Input0Data.len, 16)) |i| {
                try Cursor.writer().print("{s}{d: >4}", .{ if (i == Input0Idx) ">" else " ", Input0Data[i] });
                try Cursor.down(1);
                try Cursor.left(5);
            }

            col += 10;
        }

        if (comptime Input1Data.len > 0) {
            try Cursor.set(0, col);
            try Cursor.writer().writeAll("In 1");
            try Cursor.set(2, col);

            for (0..@min(Input1Data.len, 16)) |i| {
                try Cursor.writer().print("{s}{d: >4}", .{ if (i == Input1Idx) ">" else " ", Input1Data[i] });
                try Cursor.down(1);
                try Cursor.left(5);
            }

            col += 10;
        }

        if (comptime Input2Data.len > 0) {
            try Cursor.set(0, col);
            try Cursor.writer().writeAll("In 2");
            try Cursor.set(2, col);

            for (0..@min(Input2Data.len, 16)) |i| {
                try Cursor.writer().print("{s}{d: >4}", .{ if (i == Input2Idx) ">" else " ", Input2Data[i] });
                try Cursor.down(1);
                try Cursor.left(5);
            }

            col += 10;
        }

        if (comptime Input3Data.len > 0) {
            try Cursor.set(0, col);
            try Cursor.writer().writeAll("In 3");
            try Cursor.set(2, col);

            for (0..@min(Input3Data.len, 16)) |i| {
                try Cursor.writer().print("{s}{d: >4}", .{ if (i == Input3Idx) ">" else " ", Input3Data[i] });
                try Cursor.down(1);
                try Cursor.left(5);
            }

            col += 10;
        }

        inline for (0..4) |in| {
            const ExpectedOutput = switch (in) {
                0 => ExpectedOutput0,
                1 => ExpectedOutput1,
                2 => ExpectedOutput2,
                3 => ExpectedOutput3,
                else => unreachable,
            };

            if (ExpectedOutput.len > 0) {
                try Cursor.set(0, col);
                try Cursor.writer().writeAll("Out" ++ std.fmt.comptimePrint("{d}", .{in}));
                try Cursor.set(2, col);

                for (0..OutputIdx[in]) |i| {
                    if (i < ExpectedOutput.len and OutputData[in][i] == ExpectedOutput[i]) {
                        try Cursor.writer().writeAll(Cursor.cmd ++ "32m");
                    } else {
                        try Cursor.writer().writeAll(Cursor.cmd ++ "31m");
                    }
                    try Cursor.writer().print("{s}{d: >4}", .{ if (i == OutputIdx[in]) ">" else " ", OutputData[in][i] });
                    try Cursor.writer().writeAll(Cursor.cmd ++ "0m");
                    try Cursor.down(1);
                    try Cursor.left(5);
                }

                col += 10;

                try Cursor.set(0, col);
                try Cursor.writer().writeAll("Expected");
                try Cursor.set(2, col);

                for (0..@min(16, ExpectedOutput.len)) |i| {
                    try Cursor.writer().print("{s}{d: >4}", .{ if (i == OutputIdx[in]) ">" else " ", ExpectedOutput[i] });
                    try Cursor.down(1);
                    try Cursor.left(5);
                }

                col += 10;
            }
        }

        try Cursor.set(0, 0);

        if (OutputIdx[0] >= ExpectedOutput0.len and OutputIdx[1] >= ExpectedOutput1.len and OutputIdx[2] >= ExpectedOutput2.len and OutputIdx[3] >= ExpectedOutput3.len) {
            break;
        }
    }

    try Cursor.set(0, 0);
}
