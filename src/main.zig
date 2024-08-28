const std = @import("std");
const Cursor = @import("cursor.zig");
const tis = @import("tis.zig");

const SequenceGenerator = struct {
    const Input0Data = [_]i16{};
    const Input1Data = [_]i16{ 46, 71, 66, 21, 79, 23, 62, 23, 36, 96, 12, 97, 47 };
    const Input2Data = [_]i16{ 71, 29, 90, 67, 79, 84, 78, 27, 60, 45, 67, 42, 64 };
    const Input3Data = [_]i16{};

    var input_indices: [4]usize = .{0} ** 4;
    var output_indices: [4]usize = .{0} ** 4;

    var OutputData: [4][256]i16 = .{.{0} ** 256} ** 4;

    inline fn get_input(idx: u2) []const i16 {
        return switch (idx) {
            0 => &Input0Data,
            1 => &Input1Data,
            2 => &Input2Data,
            3 => &Input3Data,
        };
    }

    pub fn input_0() ?i16 {
        defer input_indices[0] += 1;
        return if (input_indices[0] < get_input(0).len) get_input(0)[input_indices[0]] else null;
    }

    pub fn input_1() ?i16 {
        defer input_indices[1] += 1;
        return if (input_indices[1] < get_input(1).len) get_input(1)[input_indices[1]] else null;
    }

    pub fn input_2() ?i16 {
        defer input_indices[2] += 1;
        return if (input_indices[2] < get_input(2).len) get_input(2)[input_indices[2]] else null;
    }

    pub fn input_3() ?i16 {
        defer input_indices[3] += 1;
        return if (input_indices[3] < get_input(3).len) get_input(3)[input_indices[3]] else null;
    }

    pub fn output_0(val: i16) void {
        OutputData[0][output_indices[0]] = val;
        output_indices[0] += 1;
    }

    pub fn output_1(val: i16) void {
        OutputData[1][output_indices[1]] = val;
        output_indices[1] += 1;
    }

    pub fn output_2(val: i16) void {
        OutputData[2][output_indices[2]] = val;
        output_indices[2] += 1;
    }

    pub fn output_3(val: i16) void {
        OutputData[3][output_indices[3]] = val;
        output_indices[3] += 1;
    }

    pub fn expected(output: u2, idx: usize) ?i16 {
        switch (output) {
            0 => return null,
            1 => return null,
            2 => {
                const i = @divTrunc(idx, 3);
                switch (@rem(idx, 3)) {
                    0 => return @min(Input1Data[i], Input2Data[i]),
                    1 => return @max(Input1Data[i], Input2Data[i]),
                    2 => return 0,
                    else => unreachable,
                }
            },
            3 => return null,
        }
    }
};

pub fn main() !void {
    var tis100: tis.TIS100 = .{};

    const Puzzle = SequenceGenerator;

    tis100.inputs[0] = &Puzzle.input_0;
    tis100.inputs[1] = &Puzzle.input_1;
    tis100.inputs[2] = &Puzzle.input_2;
    tis100.inputs[3] = &Puzzle.input_3;
    tis100.outputs[0] = &Puzzle.output_0;
    tis100.outputs[1] = &Puzzle.output_1;
    tis100.outputs[2] = &Puzzle.output_2;
    tis100.outputs[3] = &Puzzle.output_3;

    try tis100.nodes[1][0].set(
        \\ MOV UP DOWN
    );

    try tis100.nodes[1][1].set(
        \\ MOV UP ACC 
        \\ MOV ACC RIGHT
        \\ MOV ACC RIGHT
    );

    try tis100.nodes[2][0].set(
        \\ MOV UP ACC 
        \\ MOV ACC DOWN       
        \\ MOV ACC DOWN 
    );

    try tis100.nodes[2][1].set(
        \\ MOV UP ACC
        \\ SUB LEFT
        \\ JLZ 6
        \\ MOV LEFT DOWN
        \\ MOV UP DOWN
        \\ JMP 0
        \\ MOV UP DOWN
        \\ MOV LEFT DOWN
    );

    try tis100.nodes[2][2].set(
        \\ MOV UP DOWN
        \\ MOV UP DOWN
        \\ MOV 0 DOWN
    );

    try tis100.print();

    const stdin = std.io.getStdIn().reader();
    var buf: [256]u8 = undefined;

    while (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        if (std.mem.eql(u8, user_input, "q") or std.mem.eql(u8, user_input, "q\r")) break;

        tis100.tick();
        try tis100.print();

        comptime var col: u8 = 2 + 34 * 4;

        inline for (0..4) |in| {
            if (comptime Puzzle.get_input(in).len > 0) {
                try Cursor.set(0, col);
                try Cursor.writer().writeAll("In 2");
                try Cursor.set(2, col);

                for (0..@min(Puzzle.get_input(in).len, 32)) |i| {
                    try Cursor.writer().print("{s}{d: >4}", .{ if (i == Puzzle.input_indices[in]) ">" else " ", Puzzle.get_input(in)[i] });
                    try Cursor.down(1);
                    try Cursor.left(5);
                }

                col += 10;
            }
        }

        inline for (0..4) |in| {
            if (comptime Puzzle.expected(in, 0) != null) {
                try Cursor.set(0, col);
                try Cursor.writer().writeAll("Out" ++ std.fmt.comptimePrint("{d}", .{in}));
                try Cursor.set(2, col);

                for (0..Puzzle.output_indices[in]) |i| {
                    if (Puzzle.OutputData[in][i] == Puzzle.expected(in, i)) {
                        try Cursor.writer().writeAll(Cursor.cmd ++ "32m");
                    } else {
                        try Cursor.writer().writeAll(Cursor.cmd ++ "31m");
                    }
                    try Cursor.writer().print("{s}{d: >4}", .{ if (i == Puzzle.output_indices[in]) ">" else " ", Puzzle.OutputData[in][i] });
                    try Cursor.writer().writeAll(Cursor.cmd ++ "0m");
                    try Cursor.down(1);
                    try Cursor.left(5);
                }

                col += 10;

                try Cursor.set(0, col);
                try Cursor.writer().writeAll("Expected");
                try Cursor.set(2, col);

                for (0..@min(32, Puzzle.output_indices[in])) |i| {
                    try Cursor.writer().print("{s}{d: >4}", .{ if (i == Puzzle.output_indices[in]) ">" else " ", Puzzle.expected(in, i) orelse -1000 });
                    try Cursor.down(1);
                    try Cursor.left(5);
                }

                col += 10;
            }
        }

        try Cursor.set(0, 0);
    }

    try Cursor.set(0, 0);
}
