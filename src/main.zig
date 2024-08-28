const std = @import("std");
const Cursor = @import("cursor.zig");
const tis = @import("tis.zig");

const SequenceCounter = struct {
    const Input0Data = [_]i16{};
    const Input1Data = [_]i16{ 35, 0, 62, 51, 81, 54, 12, 0, 51, 63, 50, 67, 48, 0, 49, 23, 26, 0, 33, 79, 76, 0, 0, 94, 0, 79, 0, 98, 15, 0, 53, 35, 45, 12, 79, 0, 19, 71, 0 };
    const Input2Data = [_]i16{};
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
        const in1 = [_]i16{ 35, 260, 279, 98, 188, 0, 94, 79, 113, 224, 90 };
        const in2 = [_]i16{ 1, 5, 5, 3, 3, 0, 1, 1, 2, 5, 2 };
        switch (output) {
            0 => return null,
            1 => return if (idx < in1.len) in1[idx] else null,
            2 => return if (idx < in2.len) in2[idx] else null,
            3 => return null,
        }
    }
};

pub fn main() !void {
    var tis100: tis.TIS100 = .{};

    const Puzzle = SequenceCounter;

    tis100.inputs[0] = &Puzzle.input_0;
    tis100.inputs[1] = &Puzzle.input_1;
    tis100.inputs[2] = &Puzzle.input_2;
    tis100.inputs[3] = &Puzzle.input_3;
    tis100.outputs[0] = &Puzzle.output_0;
    tis100.outputs[1] = &Puzzle.output_1;
    tis100.outputs[2] = &Puzzle.output_2;
    tis100.outputs[3] = &Puzzle.output_3;

    try tis100.nodes[1][0].set(
        \\ MOV UP ACC
        \\ MOV ACC RIGHT
        \\ MOV ACC DOWN
    );

    try tis100.nodes[1][1].set(
        \\ MOV UP ACC
        \\ JNZ 5
        \\ MOV 0 DOWN
        \\ MOV 1 DOWN
        \\ JMP 0
        \\ MOV ACC DOWN
        \\ MOV 3 DOWN
    );

    try tis100.nodes[1][2].set(
        \\ ADD UP 
        \\ JRO UP       
        \\ MOV ACC DOWN 
        \\ MOV 0 ACC 
        \\ NOP 
    );

    try tis100.nodes[2][0].set(
        \\ MOV LEFT ACC
        \\ JNZ 5
        \\ MOV 0 DOWN
        \\ MOV 1 DOWN
        \\ JMP 0
        \\ MOV 1 DOWN
        \\ MOV 3 DOWN
    );

    try tis100.nodes[2][1].set(
        \\ ADD UP
        \\ JRO UP
        \\ MOV ACC DOWN
        \\ MOV 0 ACC
        \\ NOP
    );

    try tis100.nodes[2][2].set(
        \\ MOV UP DOWN
    );

    const stdin = std.io.getStdIn().reader();
    var buf: [256]u8 = undefined;

    var cycles: usize = 0;

    try Cursor.clear();

    const no_interaction = true;
    const render = !no_interaction or true;

    while (true) {
        const complete = Puzzle.expected(0, Puzzle.output_indices[0]) == null and Puzzle.expected(1, Puzzle.output_indices[1]) == null and Puzzle.expected(2, Puzzle.output_indices[2]) == null and Puzzle.expected(3, Puzzle.output_indices[3]) == null;

        if (render or complete) {
            try tis100.print();

            comptime var col: u8 = 2 + 34 * 4;

            inline for (0..4) |in| {
                if (comptime Puzzle.get_input(in).len > 0) {
                    try Cursor.set(0, col);
                    try Cursor.writer().writeAll("In 2");
                    try Cursor.set(2, col);

                    for (0..@min(Puzzle.get_input(in).len, 48)) |i| {
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

                    for (0..@min(48, Puzzle.output_indices[in])) |i| {
                        try Cursor.writer().print("{s}{d: >4}", .{ if (i == Puzzle.output_indices[in]) ">" else " ", Puzzle.expected(in, i) orelse -1000 });
                        try Cursor.down(1);
                        try Cursor.left(5);
                    }

                    col += 10;
                }
            }

            try Cursor.set(1, col);
            try Cursor.writer().print("Cycles: {d: >4}", .{cycles});
            try Cursor.set(0, 0);
            try Cursor.writer().writeAll("> ");
        }

        if (complete) {
            break;
        }

        if (!no_interaction) {
            const cin = try stdin.readUntilDelimiterOrEof(buf[0..], '\n');
            if (cin) |user_input| {
                if (std.mem.eql(u8, user_input, "q") or std.mem.eql(u8, user_input, "q\r")) break;
            }
        }

        tis100.tick();
        cycles += 1;
    }

    try Cursor.set(2 + 19 * 3, 0);
}
