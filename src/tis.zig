const std = @import("std");
const Cursor = @import("cursor.zig");

pub const Register = enum {
    NIL,
    ACC,
    ANY,
    LAST,
    LEFT,
    RIGHT,
    UP,
    DOWN,

    pub fn idx(self: @This()) u2 {
        return @intCast(@intFromEnum(self) - @intFromEnum(Register.LEFT));
    }
};

pub const Opcode = enum {
    NOP,
    MOV,
    SWP,
    SAV,
    ADD,
    SUB,
    NEG,
    JMP,
    JEZ,
    JNZ,
    JGZ,
    JLZ,
    JRO, // Constant JRO will be converted to absolute JMP
};

pub const OperandType = enum { Register, Immediate };

pub const Operand = union(OperandType) {
    Register: Register,
    Immediate: i16,

    pub fn format(
        instr: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try switch (instr) {
            .Register => |reg| writer.print("{s}", .{@tagName(reg)}),
            .Immediate => |imm| writer.print("{d}", .{imm}),
        };
    }
};

pub const Instruction = union(Opcode) {
    NOP: struct {},
    MOV: struct { src: Operand, dst: Register },
    SWP: struct {},
    SAV: struct {},
    ADD: struct { src: Operand },
    SUB: struct { src: Operand },
    NEG: struct {},
    JMP: struct { dst: u4 },
    JEZ: struct { dst: u4 },
    JNZ: struct { dst: u4 },
    JGZ: struct { dst: u4 },
    JLZ: struct { dst: u4 },
    JRO: struct { src: Operand },

    pub fn format(
        instr: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try switch (instr) {
            .NOP => writer.writeAll("NOP"),
            .MOV => |mov| writer.print("MOV {any} {s}", .{ mov.src, @tagName(mov.dst) }),
            .SWP => writer.writeAll("SWP"),
            .SAV => writer.writeAll("SAV"),
            .ADD => |add| writer.print("ADD {any}", .{add.src}),
            .SUB => |sub| writer.print("SUB {any}", .{sub.src}),
            .NEG => writer.writeAll("NEG"),
            .JMP => |jmp| writer.print("JMP {d}", .{jmp.dst}),
            .JEZ => |jez| writer.print("JEZ {d}", .{jez.dst}),
            .JNZ => |jnz| writer.print("JNZ {d}", .{jnz.dst}),
            .JGZ => |jgz| writer.print("JGZ {d}", .{jgz.dst}),
            .JLZ => |jlz| writer.print("JLZ {d}", .{jlz.dst}),
            .JRO => |jro| writer.print("JRO {any}", .{jro.src}),
        };
    }
};

pub const Node = struct {
    acc: i16 = 0,
    bak: i16 = 0,

    instructions: [15]Instruction = .{.{ .NOP = .{} }} ** 15,
    instr_count: u4 = 0,
    pc: u4 = 0,

    ports: [4]?i16 = .{ null, null, null, null },
    last_port: ?Register = null, // Last used port

    next_ports: [4]?i16 = .{ null, null, null, null },

    pub fn append(self: *@This(), instr: Instruction) void {
        self.instructions[self.instr_count] = instr;
        self.instr_count += 1;
    }

    pub fn set(self: *@This(), source: []const u8) !void {
        const t = try parse(source);
        self.instructions = t.instructions;
        self.instr_count = t.instr_count;
    }

    inline fn read_port(self: *@This(), comptime reg: Register) ?i16 {
        if (self.ports[reg.idx()]) |port| {
            self.last_port = reg;
            self.ports[reg.idx()] = null;
            self.pc += 1;
            self.pc %= self.instr_count;
            return port;
        }
        return null;
    }

    pub fn up(self: *@This()) ?i16 {
        return self.read_port(Register.UP);
    }
    pub fn down(self: *@This()) ?i16 {
        return self.read_port(Register.DOWN);
    }
    pub fn left(self: *@This()) ?i16 {
        return self.read_port(Register.LEFT);
    }
    pub fn right(self: *@This()) ?i16 {
        return self.read_port(Register.RIGHT);
    }

    pub fn print(self: *const @This()) !void {
        const stdout = std.io.getStdOut().writer();

        try Cursor.save();
        try stdout.writeAll(".------------------.-----------.");
        try Cursor.down(1);
        try Cursor.left(32);
        for (0..self.instructions.len) |_| {
            try stdout.writeAll("|                  |           |");
            try Cursor.down(1);
            try Cursor.left(32);
        }
        try stdout.writeAll("'------------------'-----------'");
        try Cursor.restore();
        try Cursor.down(1);

        try Cursor.save();
        try Cursor.right(21);
        try stdout.writeAll("ACC:      |");
        try Cursor.left(11 - 5);
        try stdout.print("{d: >4}", .{self.acc});
        try Cursor.left(4 + 5);
        try Cursor.down(1);
        try stdout.writeAll("BAK:      |");
        try Cursor.left(11 - 5);
        try stdout.print("{d: >4}", .{self.bak});
        try Cursor.left(10);
        try Cursor.down(2);
        if (self.ports[Register.UP.idx()]) |port| {
            try stdout.print("    {d: <4}", .{port});
            try Cursor.left(8);
        } else {
            try stdout.writeAll("     -");
            try Cursor.left(6);
        }
        try Cursor.down(1);
        if (self.ports[Register.LEFT.idx()]) |port| {
            try stdout.print("{d: <4}", .{port});
        } else {
            try stdout.writeAll("   -");
        }
        if (self.ports[Register.RIGHT.idx()]) |port| {
            try stdout.print("{d: >4}", .{port});
        } else {
            try stdout.writeAll("   -");
        }
        try Cursor.left(8);
        try Cursor.down(1);
        if (self.ports[Register.DOWN.idx()]) |port| {
            try stdout.print("    {d: <4}", .{port});
            try Cursor.left(8);
        } else {
            try stdout.writeAll("     -");
            try Cursor.left(6);
        }
        try Cursor.restore();

        for (0..self.instr_count) |i| {
            try Cursor.save();
            try stdout.print("|{s}{s}" ++ Cursor.cmd ++ "0;0m", .{ if (i == self.pc) Cursor.cmd ++ "47;30m>" else " ", self.instructions[i] });
            try Cursor.restore();
            try Cursor.right(18);
            try stdout.writeAll(" |");
            try Cursor.restore();
            try Cursor.down(1);
        }
    }
};

pub const TIS100 = struct {
    nodes: [4][3]Node = .{.{.{}} ** 3} ** 4,

    inputs: [4]?*const fn () ?i16 = .{null} ** 4,
    outputs: [4]?*const fn (i16) void = .{null} ** 4,

    pub fn tick(self: *@This()) void {
        for (0..4) |i| {
            for (0..3) |j| {
                const node = &self.nodes[i][j];
                if (node.instr_count > 0) {
                    // Some outputs haven't been consumed yet. Wait.
                    if (node.ports[0] != null or node.ports[1] != null or node.ports[2] != null or node.ports[3] != null) {
                        continue;
                    }

                    switch (node.instructions[node.pc]) {
                        .MOV => |instr| {
                            if (self.get(i, j, instr.src)) |val| {
                                switch (instr.dst) {
                                    .ACC => {
                                        node.acc = val;
                                        node.pc += 1;
                                    },
                                    .UP, .DOWN, .LEFT, .RIGHT => |reg| node.next_ports[reg.idx()] = val,
                                    .NIL => node.pc += 1,
                                    else => @panic("Unimplemented destination"),
                                }
                            }
                        },
                        .SWP => {
                            std.mem.swap(i16, &node.acc, &node.bak);
                            node.pc += 1;
                        },
                        .SAV => {
                            node.acc = node.bak;
                            node.pc += 1;
                        },
                        .ADD => |instr| {
                            if (self.get(i, j, instr.src)) |val| {
                                node.acc += val;
                                node.pc += 1;
                            }
                        },
                        .SUB => |instr| {
                            if (self.get(i, j, instr.src)) |val| {
                                node.acc -= val;
                                node.pc += 1;
                            }
                        },
                        .NEG => {
                            node.acc = -node.acc;
                            node.pc += 1;
                        },
                        .JMP => |instr| node.pc = instr.dst,
                        .JEZ => |instr| {
                            if (node.acc == 0) node.pc = instr.dst else node.pc += 1;
                        },
                        .JNZ => |instr| {
                            if (node.acc != 0) node.pc = instr.dst else node.pc += 1;
                        },
                        .JGZ => |instr| {
                            if (node.acc > 0) node.pc = instr.dst else node.pc += 1;
                        },
                        .JLZ => |instr| {
                            if (node.acc < 0) node.pc = instr.dst else node.pc += 1;
                        },
                        .JRO => |instr| {
                            if (self.get(i, j, instr.src)) |val| {
                                node.pc = @intCast(@as(i16, @intCast(node.pc)) +% val);
                            }
                        },
                        .NOP => {
                            node.pc += 1;
                        },
                    }
                    node.pc %= node.instr_count;
                }
            }
        }

        // Pull outputs
        for (0..4) |i| {
            if (self.nodes[i][2].down()) |val| {
                if (self.outputs[i]) |output_fn| {
                    output_fn(val);
                }
            }
        }

        // Commit updates
        // NOTE: This delay all communication between nodes by one cycle. I don't know how to solve this elegantly yet.
        for (&self.nodes) |*col| {
            for (col) |*node| {
                for (0..4) |i| {
                    if (node.next_ports[i]) |port| {
                        node.ports[i] = port;
                        node.next_ports[i] = null;
                    }
                }
            }
        }
    }

    pub fn get(self: *@This(), i: usize, j: usize, operand: Operand) ?i16 {
        switch (operand) {
            .Register => |reg| switch (reg) {
                .NIL => return 0,
                .ACC => return self.nodes[i][j].acc,
                .UP => return if (j == 0) (if (self.inputs[i] != null) self.inputs[i].?() else null) else self.nodes[i][j - 1].down(),
                .DOWN => return if (j >= self.nodes[i].len - 1) null else self.nodes[i][j + 1].up(),
                .LEFT => return if (i == 0) null else self.nodes[i - 1][j].right(),
                .RIGHT => return if (i >= self.nodes.len - 1) null else self.nodes[i + 1][j].left(),
                .LAST => return self.get(i, j, .{ .Register = self.nodes[i][j].last_port orelse .NIL }),
                .ANY => {
                    if (self.get(i, j, .{ .Register = .LEFT })) |val| return val;
                    if (self.get(i, j, .{ .Register = .RIGHT })) |val| return val;
                    if (self.get(i, j, .{ .Register = .UP })) |val| return val;
                    if (self.get(i, j, .{ .Register = .DOWN })) |val| return val;
                    return null;
                },
            },
            .Immediate => |imm| return imm,
        }
    }

    pub fn print(self: *const @This()) !void {
        try Cursor.clear();

        inline for (0..4) |i| {
            inline for (0..3) |j| {
                try Cursor.set(1 + 19 * j, 34 * i);
                try self.nodes[i][j].print();
            }
        }

        try Cursor.set(0, 0);
    }
};

fn trim_start(input: []const u8) []const u8 {
    var start: usize = 0;
    while (start < input.len and input[start] == ' ') start += 1;
    return input[start..];
}

fn next_operand(line: []const u8) []const u8 {
    const trimmed = trim_start(line);
    return trimmed[0 .. std.mem.indexOf(u8, trimmed, " ") orelse trimmed.len];
}

fn parse_register(op: []const u8) !?Register {
    if (std.mem.eql(u8, op, "NIL")) return .NIL;
    if (std.mem.eql(u8, op, "ACC")) return .ACC;
    if (std.mem.eql(u8, op, "UP")) return .UP;
    if (std.mem.eql(u8, op, "DOWN")) return .DOWN;
    if (std.mem.eql(u8, op, "LEFT")) return .LEFT;
    if (std.mem.eql(u8, op, "RIGHT")) return .RIGHT;
    if (std.mem.eql(u8, op, "LAST")) return .LAST;
    if (std.mem.eql(u8, op, "ANY")) return .ANY;
    return null;
}

fn parse_operand(op: []const u8) !Operand {
    if (try parse_register(op)) |reg| return .{ .Register = reg };
    return .{ .Immediate = try std.fmt.parseInt(i16, op, 10) };
}

pub fn parse(txt: []const u8) !struct { instructions: [15]Instruction, instr_count: u4 } {
    var lines = std.mem.splitSequence(u8, txt, "\n");

    var instructions: [15]Instruction = .{.NOP} ** 15;
    var idx: usize = 0;

    while (lines.next()) |line| {
        var l = trim_start(line);
        if (l.len < 3) return error.InvalidInstruction;
        const op = l[0..3];
        if (std.mem.eql(u8, op, "MOV")) {
            const rest = trim_start(l[3..]);
            const src = next_operand(rest);
            const dst = next_operand(rest[src.len..]);
            const dst_reg = try parse_register(dst);
            if (dst_reg == null) return error.InvalidDestinationRegister;
            instructions[idx] = .{ .MOV = .{ .src = try parse_operand(src), .dst = dst_reg.? } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "SWP")) {
            instructions[idx] = .SWP;
            idx += 1;
        } else if (std.mem.eql(u8, op, "SAV")) {
            instructions[idx] = .SAV;
            idx += 1;
        } else if (std.mem.eql(u8, op, "NEG")) {
            instructions[idx] = .NEG;
            idx += 1;
        } else if (std.mem.eql(u8, op, "ADD")) {
            instructions[idx] = .{ .ADD = .{ .src = try parse_operand(next_operand(l[3..])) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "SUB")) {
            instructions[idx] = .{ .SUB = .{ .src = try parse_operand(next_operand(l[3..])) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "JMP")) {
            instructions[idx] = .{ .JMP = .{ .dst = try std.fmt.parseInt(u4, next_operand(l[3..]), 10) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "JEZ")) {
            instructions[idx] = .{ .JEZ = .{ .dst = try std.fmt.parseInt(u4, next_operand(l[3..]), 10) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "JNZ")) {
            instructions[idx] = .{ .JNZ = .{ .dst = try std.fmt.parseInt(u4, next_operand(l[3..]), 10) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "JGZ")) {
            instructions[idx] = .{ .JGZ = .{ .dst = try std.fmt.parseInt(u4, next_operand(l[3..]), 10) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "JLZ")) {
            instructions[idx] = .{ .JLZ = .{ .dst = try std.fmt.parseInt(u4, next_operand(l[3..]), 10) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "JRO")) {
            instructions[idx] = .{ .JRO = .{ .src = try parse_operand(l[3..]) } };
            idx += 1;
        } else {
            return error.InvalidInstruction;
        }
    }

    return .{ .instructions = instructions, .instr_count = @truncate(idx) };
}

///////////////////////////////////////////////////////////////////////////////
// TESTS

const TestInputData = [_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

fn test_input() ?i16 {
    const static = struct {
        var idx: usize = 0;
    };
    defer static.idx += 1;
    return TestInputData[static.idx];
}

fn sequential_output(val: i16) void {
    const static = struct {
        var expected_val: i16 = 1;
    };
    std.testing.expect(val == static.expected_val) catch |err|
        @panic(@errorName(err));
    static.expected_val += 1;
}

test {
    var tis100: TIS100 = .{};

    tis100.inputs[0] = &test_input;
    tis100.outputs[0] = &sequential_output;

    tis100.nodes[0][0].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .DOWN } });
    tis100.nodes[0][1].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .DOWN } });
    tis100.nodes[0][2].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .DOWN } });

    for (0..TestInputData.len + 4) |_| {
        tis100.tick();
    }
}

const DoubleInputData = [_]i16{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
const DoubleExpectedOutput: [16]i16 = .{ 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30 };

fn double_input() ?i16 {
    const static = struct {
        var idx: usize = 0;
    };
    defer static.idx += 1;
    return DoubleInputData[static.idx];
}

fn double_output(val: i16) void {
    const static = struct {
        var idx: usize = 0;
    };
    std.testing.expect(val == DoubleExpectedOutput[static.idx]) catch |err|
        @panic(@errorName(err));
    static.idx += 1;
}

test {
    var tis100: TIS100 = .{};

    tis100.inputs[0] = &double_input;
    tis100.outputs[0] = &double_output;

    tis100.nodes[0][0].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .DOWN } });

    tis100.nodes[0][1].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .ACC } });
    tis100.nodes[0][1].append(.{ .ADD = .{ .src = .{ .Register = .ACC } } });
    tis100.nodes[0][1].append(.{ .MOV = .{ .src = .{ .Register = .ACC }, .dst = .DOWN } });

    tis100.nodes[0][2].append(.{ .MOV = .{ .src = .{ .Register = .UP }, .dst = .DOWN } });

    for (0..3 * DoubleInputData.len + 4) |_| {
        tis100.tick();
    }
}

const DifferentialConverter = struct {
    const Input0Data = [_]i16{};
    const Input1Data = [_]i16{ 44, 78, 88, 95, 65, 63, 41, 26, 87, 75, 21, 21, 62, 43, 26, 45, 13, 26, 30, 33, 34, 24, 39, 55, 54, 52, 67, 18, 77, 41, 31, 68, 28, 19, 97, 76, 27, 55, 89 };
    const Input2Data = [_]i16{ 93, 60, 92, 68, 56, 30, 90, 65, 94, 92, 62, 35, 63, 57, 45, 40, 81, 11, 35, 20, 85, 29, 86, 84, 36, 18, 33, 87, 87, 54, 82, 69, 31, 18, 79, 24, 34, 67, 74 };
    const Input3Data = [_]i16{};

    pub fn input_0() ?i16 {
        const static = struct {
            var idx: usize = 0;
        };
        defer static.idx += 1;
        return if (static.idx < Input0Data.len) Input0Data[static.idx] else null;
    }

    pub fn input_1() ?i16 {
        const static = struct {
            var idx: usize = 0;
        };
        defer static.idx += 1;
        return if (static.idx < Input1Data.len) Input1Data[static.idx] else null;
    }

    pub fn input_2() ?i16 {
        const static = struct {
            var idx: usize = 0;
        };
        defer static.idx += 1;
        return if (static.idx < Input2Data.len) Input2Data[static.idx] else null;
    }

    pub fn input_3() ?i16 {
        const static = struct {
            var idx: usize = 0;
        };
        defer static.idx += 1;
        return if (static.idx < Input3Data.len) Input3Data[static.idx] else null;
    }

    pub fn output_0(_: i16) void {}

    pub fn output_1(val: i16) void {
        const static = struct {
            var idx: usize = 0;
        };
        std.testing.expect(val == Input1Data[static.idx] - Input2Data[static.idx]) catch |err|
            @panic(@errorName(err));
        static.idx += 1;
    }

    pub fn output_2(val: i16) void {
        const static = struct {
            var idx: usize = 0;
        };
        std.testing.expect(val == Input2Data[static.idx] - Input1Data[static.idx]) catch |err|
            @panic(@errorName(err));
        static.idx += 1;
    }

    pub fn output_3(_: i16) void {}
};

test {
    var tis100: TIS100 = .{};

    tis100.inputs[0] = &DifferentialConverter.input_0;
    tis100.inputs[1] = &DifferentialConverter.input_1;
    tis100.inputs[2] = &DifferentialConverter.input_2;
    tis100.inputs[3] = &DifferentialConverter.input_3;
    tis100.outputs[0] = &DifferentialConverter.output_0;
    tis100.outputs[1] = &DifferentialConverter.output_1;
    tis100.outputs[2] = &DifferentialConverter.output_2;
    tis100.outputs[3] = &DifferentialConverter.output_3;

    try tis100.nodes[1][0].set("MOV UP RIGHT");

    try tis100.nodes[1][2].set(
        \\ MOV RIGHT ACC
        \\ NEG
        \\ MOV ACC DOWN
    );

    try tis100.nodes[2][0].set(
        \\ MOV UP ACC 
        \\ SUB LEFT
        \\ MOV ACC DOWN
    );

    try tis100.nodes[2][1].set("MOV UP DOWN");

    try tis100.nodes[2][2].set(
        \\ MOV UP ACC
        \\ MOV ACC LEFT
        \\ MOV ACC DOWN
    );

    for (0..3 * DifferentialConverter.Input0Data.len + 4) |_| {
        tis100.tick();
    }
}
