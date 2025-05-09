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

const NodeType = enum {
    ExecutionNode,
    StackMemoryNode,
};

pub const Node = union(NodeType) {
    ExecutionNode: ExecutionNode,
    StackMemoryNode: StackMemoryNode,
};

pub const ExecutionNode = struct {
    acc: i16 = 0,
    bak: i16 = 0,

    instructions: [15]Instruction = @splat(.NOP),
    instr_count: u4 = 0,
    pc: u4 = 0,

    ports: [4]?i16 = @splat(null),
    last_port: ?Register = null, // Last used port

    next_ports: [4]?i16 = @splat(null),

    rendered: bool = false,

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
        if (self.instr_count == 0 and self.rendered) {
            return;
        }

        const stdout = std.io.getStdOut().writer();
        if (!self.rendered) {
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
        }
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
            if (i == self.pc)
                try stdout.writeAll(Cursor.cmd ++ "47;30m");
            try Cursor.right(1);
            try stdout.writeAll("                  ");
            try Cursor.restore();
            try Cursor.right(1);
            if (i == self.pc)
                try stdout.writeAll(Cursor.cmd ++ "47;30m");
            try stdout.print(" {s}" ++ Cursor.cmd ++ "0;0m", .{self.instructions[i]});
            try Cursor.restore();
            try Cursor.down(1);
        }

        @constCast(self).rendered = true;
    }
};

pub const StackMemoryNode = struct {
    stack: [15]i16 = .{0} ** 15,
    count: u4 = 0,

    pub fn read_port(self: *@This()) ?i16 {
        if (self.count > 0) {
            self.count -= 1;
            return self.stack[self.count];
        }
        return null;
    }

    pub fn push(self: *@This(), val: i16) void {
        self.stack[self.count] = val;
        self.count += 1;
    }
};

pub const TIS100 = struct {
    nodes: [4][3]ExecutionNode = @splat(@splat(.{})),

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
        // NOTE: This delays all communication between nodes by one cycle.
        //       We could re-run the nodes that stalled because their output wasn't consumed yet,
        //       but it looks less accurate. Maybe the game does exactly that?
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
        return switch (operand) {
            .Register => |reg| switch (reg) {
                .NIL => 0,
                .ACC => self.nodes[i][j].acc,
                .UP => if (j == 0) (if (self.inputs[i] != null) self.inputs[i].?() else null) else self.nodes[i][j - 1].down(),
                .DOWN => if (j >= self.nodes[i].len - 1) null else self.nodes[i][j + 1].up(),
                .LEFT => if (i == 0) null else self.nodes[i - 1][j].right(),
                .RIGHT => if (i >= self.nodes.len - 1) null else self.nodes[i + 1][j].left(),
                .LAST => self.get(i, j, .{ .Register = self.nodes[i][j].last_port orelse .NIL }),
                .ANY => self.get(i, j, .{ .Register = .LEFT }) orelse self.get(i, j, .{ .Register = .RIGHT }) orelse self.get(i, j, .{ .Register = .UP }) orelse self.get(i, j, .{ .Register = .DOWN }) orelse null,
            },
            .Immediate => |imm| imm,
        };
    }

    pub fn print(self: *const @This()) !void {
        inline for (0..4) |i| {
            inline for (0..3) |j| {
                try Cursor.set(1 + 18 * j, 34 * i);
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
    var idx: u4 = 0;

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
            instructions[idx] = .{ .JRO = .{ .src = try parse_operand(next_operand(l[3..])) } };
            idx += 1;
        } else if (std.mem.eql(u8, op, "NOP")) {
            instructions[idx] = .NOP;
            idx += 1;
        } else {
            return error.InvalidInstruction;
        }
        if (idx >= 15) break;
    }

    return .{ .instructions = instructions, .instr_count = idx };
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

const SignalComparator = struct {
    const Input0Data = [_]i16{ 2, 1, 2, 0, -2, 1, 2, -2, -1, -2, 1, -2, 0, 2, 0, 1, 0, 2, -1, 0, -1, -1, -1, 0, 1, 1, -2, -2, -2, 2, -2, 0, 2, -1, 1, 2, 0, -1, -1 };
    const Input1Data = [_]i16{};
    const Input2Data = [_]i16{};
    const Input3Data = [_]i16{};

    var input_indices: [4]usize = .{0} ** 4;
    var output_indices: [4]usize = .{0} ** 4;

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
        std.testing.expect(val == expected(0, output_indices[0])) catch |err|
            @panic(@errorName(err));
        output_indices[0] += 1;
    }

    pub fn output_1(val: i16) void {
        std.testing.expect(val == expected(1, output_indices[1])) catch |err|
            @panic(@errorName(err));
        output_indices[1] += 1;
    }

    pub fn output_2(val: i16) void {
        std.testing.expect(val == expected(2, output_indices[2])) catch |err|
            @panic(@errorName(err));
        output_indices[2] += 1;
    }

    pub fn output_3(val: i16) void {
        std.testing.expect(val == expected(3, output_indices[3])) catch |err|
            @panic(@errorName(err));
        output_indices[3] += 1;
    }

    pub fn expected(output: u2, idx: usize) ?i16 {
        switch (output) {
            0 => return null,
            1 => return if (get_input(0)[idx] > 0) 1 else 0,
            2 => return if (get_input(0)[idx] == 0) 1 else 0,
            3 => return if (get_input(0)[idx] < 0) 1 else 0,
        }
    }
};

test {
    var tis100: TIS100 = .{};

    const Puzzle = SignalComparator;
    tis100.inputs[0] = &Puzzle.input_0;
    tis100.inputs[1] = &Puzzle.input_1;
    tis100.inputs[2] = &Puzzle.input_2;
    tis100.inputs[3] = &Puzzle.input_3;
    tis100.outputs[0] = &Puzzle.output_0;
    tis100.outputs[1] = &Puzzle.output_1;
    tis100.outputs[2] = &Puzzle.output_2;
    tis100.outputs[3] = &Puzzle.output_3;

    try tis100.nodes[0][0].set("MOV UP DOWN");
    try tis100.nodes[0][1].set("MOV UP DOWN");
    try tis100.nodes[0][2].set("MOV UP RIGHT");

    try tis100.nodes[1][2].set(
        \\ MOV LEFT ACC 
        \\ MOV ACC RIGHT
        \\ JGZ 5        
        \\ MOV 0 DOWN   
        \\ JMP 0        
        \\ MOV 1 DOWN   
    );

    try tis100.nodes[2][2].set(
        \\ MOV LEFT ACC 
        \\ MOV ACC RIGHT
        \\ JEZ 5        
        \\ MOV 0 DOWN   
        \\ JMP 0        
        \\ MOV 1 DOWN   
    );

    try tis100.nodes[3][2].set(
        \\ MOV LEFT ACC 
        \\ JLZ 4        
        \\ MOV 0 DOWN   
        \\ JMP 0        
        \\ MOV 1 DOWN   
    );

    for (0..5 * Puzzle.Input0Data.len + 4) |_| {
        tis100.tick();
    }
}

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

test {
    var tis100: TIS100 = .{};

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

    for (0..5 * Puzzle.Input0Data.len + 4) |_| {
        tis100.tick();
    }
}

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

test {
    var tis100: TIS100 = .{};

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

    while (Puzzle.expected(0, Puzzle.output_indices[0]) != null and Puzzle.expected(1, Puzzle.output_indices[1]) != null and Puzzle.expected(2, Puzzle.output_indices[2]) != null and Puzzle.expected(3, Puzzle.output_indices[3]) != null) {
        tis100.tick();
    }

    for (0..4) |in| {
        for (0..Puzzle.output_indices[in]) |i| {
            try std.testing.expect(Puzzle.expected(@intCast(in), i) == Puzzle.OutputData[in][i]);
        }
    }
}
