const std = @import("std");
const allocator = std.heap.page_allocator;
// const SDL = @import("sdl_lib");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

const print = std.debug.print;

const FONTSET = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};
const timer = struct {
    time: u8 = undefined,

    fn init(self: *@This(), time: u8) void {
        self.time = time;
    }

    fn countdown(self: *@This()) void {
        self.time -= 1;
    }
};

fn init0u8Array(array: []u8) void {
    for (0..array.len) |i| {
        array[i] = 0;
    }
}

fn init0u2Array(array: []u2) void {
    for (0..array.len) |i| {
        array[i] = 0;
    }
}

const keymap = [_]struct {c_uint, u4, *const [1:0]u8}{
    .{ c.SDLK_1, 0x1, "1"}, .{ c.SDLK_2, 0x2, "2" }, .{ c.SDLK_3, 0x3, "3" }, .{ c.SDLK_4, 0xC, "4" }, 
    .{c.SDLK_Q, 0x4, "Q"}, .{ c.SDLK_W, 0x5, "w"}, .{ c.SDLK_E, 0x6, "e"}, .{ c.SDLK_R, 0xD, "r"}, 
    .{ c.SDLK_A, 0x7, "a"}, .{ c.SDLK_S, 0x8, "s" }, .{ c.SDLK_D, 0x9, "d"}, .{ c.SDLK_F, 0xE, "f"}, 
    .{ c.SDLK_Z, 0xA, "z" }, .{ c.SDLK_X, 0x0, "x"}, .{ c.SDLK_C, 0xB, "c" }, .{ c.SDLK_V, 0xF, "v"} };

const gfxHeight = 32;
const gfxWidth = 64;
const cellSize = 10;
///defines a chip-8 cpu made of all its components
const CPU = struct {
    ///current instruction
    opcode: u16 = undefined,
    memory: [4096]u8 = undefined,
    ///registers
    V: [16]u8 = undefined,
    ///current index register
    I: u16 = undefined,
    ///program counter
    pc: u16 = undefined,
    ///graphics
    gfx: [gfxHeight * gfxWidth]u2 = undefined,

    //timers
    delay_timer: timer = timer{},
    sound_timer: timer = timer{},

    ///program stack
    stack: [16]u16 = undefined,
    ///stack pointer
    sp: u5 = undefined,
    drawFlag: bool = false,

    key: [16]bool = undefined,
    romPath: []const u8 = undefined,

    // 0x000-0x1FF - Chip 8 interpreter (contains font set in emu)
    // 0x050-0x0A0 - Used for the built in 4x5 pixel font set (0-F)
    // 0x200-0xFFF - Program ROM and work RAM

    ///Initializes the CPU
    /// - clears memory, registers and graphics
    /// - resets program values
    /// - loads the fontset
    pub fn init(self: *@This()) void {
        //init/clear memory
        init0u8Array(&self.memory);
        init0u8Array(&self.V);
        init0u2Array(&self.gfx);
        @memset(&self.stack, 0);
        // @memset(&self.gfx, 0);
        @memset(&self.key, false);

        //reset values
        self.pc = 0x200;
        self.I = 0;
        self.sp = 0;
        self.opcode = 0;
        self.drawFlag = false;

        // Load fontset
        for (0..FONTSET.len) |i| {
            self.memory[i] = FONTSET[i];
        }
    }
    ///Loads a chip-8 program to be executed
    fn loadExe(self: *@This(), file_path: []const u8) !void {
        self.romPath = file_path;
        const rom = try std.fs.cwd().openFile(file_path, .{});
        defer rom.close();
        const stats = try rom.stat();
        const buf: []u8 = try rom.readToEndAlloc(allocator, stats.size);
        print("Reading bytes...\n", .{});
        for (0..buf.len) |i| {
            const byte = buf[i];
            self.memory[i + self.pc] = byte;
            // print("0x{x} ", .{byte});
        }
    }

     fn reload(self: *@This()) !void {
        try self.loadExe(self.romPath);
    }

    pub fn cycle(self: *@This()) !void {
        //fetch
        self.opcode = @as(u16, self.memory[self.pc]) << 8 | self.memory[self.pc + 1];
        self.pc += 2; // increment to next opcode

        //handle opcode (decode & execute)
        switch (self.opcode & 0xF000) {
            0x0000 => { // multiple cases for 0x00__
                switch (self.opcode & 0x000F) {
                    0x0000 => { // 00E0 (clears thw screen)
                        @memset(&self.gfx, 0);
                    },
                    0x000E => { // 00EE (returns from a subroutine)
                        self.sp -= 1;
                        self.pc = self.stack[self.sp];
                    },
                    else => {
                        print("Opcode 0x0___: 0x{x} not handled", .{self.opcode});
                        return error.OpcodeNotDecoded;
                    },
                }
            },
            0x1000 => { // 1NNN (jump)
                self.pc = self.opcode & 0x0FFF;
            },
            0x2000 => { // 2NNN (subroutine @ address NNN)
                self.stack[self.sp] = self.pc;
                self.sp += 1;
                self.pc = self.opcode & 0x0FFF;
            },
            0x3000 => { // 3XNN (if Vx == NN) skip next instruction
                const x = (self.opcode & 0x0F00) >> 8;
                if (self.V[x] == @as(u8, @truncate(self.opcode))) {
                    self.pc += 2;
                }
            },
            0x4000 => { // 4XNN (if Vx != NN) skip next instruction
                const x = (self.opcode & 0x0F00) >> 8;
                if (self.V[x] != @as(u8, @truncate(self.opcode))) {
                    self.pc += 2;
                }
            },
            0x5000 => { // 5XY0 (if Vx == Vy) skip next instruction
                const x = (self.opcode & 0x0F00) >> 8;
                const y = (self.opcode & 0x00F0) >> 4;
                if (self.V[x] == self.V[y]) {
                    self.pc += 2;
                }
            },
            0x6000 => { // 6XNN (set register VX)
                const X = (self.opcode & 0x0F00) >> 8;
                self.V[X] = @truncate(self.opcode);
            },
            0x7000 => { // 7XNN (add value to register VX)
                const x = (self.opcode & 0x0F00) >> 8;
                // print("V[x] {d} + NN {d}\n", .{self.V[x], @as(u8, @truncate(self.opcode))});
                const result = @addWithOverflow(self.V[x], @as(u8, @truncate(self.opcode)));
                self.V[x] = result[0];
            },
            0x8000 => {
                switch (self.opcode & 0x000F) {
                    0x0000 => { // 8XY0 (sets the value of Vx to the value of Vy)
                        const x = (self.opcode & 0x0F00) >> 8;
                        const y = (self.opcode & 0x00F0) >> 4;
                        self.V[x] = self.V[y];
                    },
                    0x0001 => { // 8XY1 (Sets VX to VX or VY. (bitwise OR operation))
                        const x = (self.opcode & 0x0F00) >> 8;
                        const y = (self.opcode & 0x00F0) >> 4;
                        self.V[x] |= self.V[y];
                    },
                    0x0002 => { // 8XY2 (Sets VX to VX and VY. (bitwise AND operation))
                        const x = (self.opcode & 0x0F00) >> 8;
                        const y = (self.opcode & 0x00F0) >> 4;
                        self.V[x] &= self.V[y];
                    },
                    0x0003 => { // 8XY3 (Sets VX to VX xor VY)
                        const x = (self.opcode & 0x0F00) >> 8;
                        const y = (self.opcode & 0x00F0) >> 4;
                        self.V[x] ^= self.V[y];
                    },
                    0x0004 => { // 8XY4 (Sets VX to VX + VY)
                        const x = (self.opcode & 0x0F00) >> 8;
                        const y = (self.opcode & 0x00F0) >> 4;
                        // print("Vx {d} + Vy {d}\n", .{self.V[x], self.V[y]});
                        const result = @addWithOverflow(self.V[x], self.V[y]);
                        self.V[x] = result[0];
                        self.V[0xF] = result[1];
                        // print("= {d} : carry {d}\n", .{self.V[x], self.V[0xF]});
                    },
                    0x0005 => { // 8XY5 (Sets VX to VX - VY)
                        const x = (self.opcode & 0x0F00) >> 8;
                        const y = (self.opcode & 0x00F0) >> 4;
                        // print("V[x] {d} - V[y] {d}\n", .{self.V[x], self.V[y]});
                        const result = @subWithOverflow(self.V[x], self.V[y]);
                        self.V[x] = result[0];
                        self.V[0xF] = result[1] ^ 1; 
                        // print("= {d} : carry {d}\n", .{self.V[x], self.V[0xF]});
                    },
                    0x0006 => { // 8XY6 Shifts VX to the right by 1, then stores the least significant bit of VX prior to the shift into VF)
                        const x = (self.opcode & 0x0F00) >> 8;
                        const prior = self.V[x];
                        self.V[x] = self.V[x] >> 1;
                        self.V[0xF] = @as(u1, @truncate(prior));
                    },
                    0x0007 => { // 8XY7 (Sets VX to VY - VX)
                        const x = (self.opcode & 0x0F00) >> 8;
                        const y = (self.opcode & 0x00F0) >> 4;
                        // print("V[y] {d} - V[x] {d}\n", .{self.V[y], self.V[x]});
                        const result = @subWithOverflow(self.V[y], self.V[x]);
                        self.V[x] = result[0];
                        self.V[0xF] = result[1] ^ 1; 
                        // print("= {d} : carry {d}\n", .{self.V[x], self.V[0xF]});
                    },
                    0x000E => { // 8XYE Shifts VX to the left by 1, then sets VF to 1 if the most significant bit of VX prior to that shift was set, or to 0 if it was unset.
                        const x = (self.opcode & 0x0F00) >> 8;
                        const prior = self.V[x];
                        self.V[x] = self.V[x] << 1;
                        self.V[0xF] = @as(u1, @truncate(prior >> 7));
                    },
                    else => {
                        print("Opcode 0x8___: 0x{x} not handled", .{self.opcode});
                        return error.OpcodeNotDecoded;
                    },
                }
            },
            0x9000 => { //9XY0 if (Vx != Vy)	Skips the next instruction if VX does not equal VY. (Usually the next instruction is a jump to skip a code block)
                const x = (self.opcode & 0x0F00) >> 8;
                const y = (self.opcode & 0x00F0) >> 4;
                if (self.V[x] != self.V[y]) {
                    self.pc += 2;
                }
            },
            0xA000 => { // ANNN Sets the I address to NNN
                self.I = self.opcode & 0x0FFF;
            },
            0xB000 => { //BXNN PC = V0 + NNN	Jumps to the address NNN plus V0
                const x = (self.opcode & 0x0F00) >> 8;
                self.pc = (self.opcode & 0x0FFF) + self.V[x];
            },
            0xC000 => { //CXNN Vx = rand() & NN	Sets VX to the result of a bitwise and operation on a random number (Typically: 0 to 255) and NN
                const x = (self.opcode & 0x0F00) >> 8;
                var prng = std.rand.DefaultPrng.init(blk: {
                    var seed: u64 = undefined;
                    try std.posix.getrandom(std.mem.asBytes(&seed));
                    break :blk seed;
                });
                const rand = prng.random();
                self.V[x] &= rand.intRangeAtMost((u8), 0, 255);
            },
            0xD000 => { // DXYN (display/draw)

                const X = (self.opcode & 0x0F00) >> 8;
                const Y = (self.opcode & 0x00F0) >> 4;
                const height = self.opcode & 0x000F;
                const xPos = self.V[X] % gfxWidth;
                const yPos = self.V[Y] % gfxHeight;
                // print("pos: x-{d} y-{d}\n", .{xPos, yPos});
                self.V[0xF] = 0;
                for (0..height) |row| {
                    const spriteByte = self.memory[self.I + row];
                    for (0..8) |col| {
                        const shift: u16 = @as(u16, 0x80) >> @as(u3, @truncate(col));
                        const spritePixel = spriteByte & shift;
                        // const screenPixel = self.gfx[(yPos + row) * gfxWidth + (xPos + col)];
                        if (spritePixel != 0 and (yPos + row) * gfxWidth + (xPos + col) < gfxHeight * gfxWidth) {
                            // Screen pixel also on - collision
                            if (self.gfx[(yPos + row) * gfxWidth + (xPos + col)] == 1) {
                                self.V[0xF] = 1;
                            }

                            // Effectively XOR with the sprite pixel
                            self.gfx[(yPos + row) * gfxWidth + (xPos + col)] ^= 1;
                        }
                    }
                }
                self.drawFlag = true;
            },
            0xE000 => {
                switch (self.opcode & 0x000F) {
                    0x0001 => { // EXA1 if (key() != Vx)	Skips the next instruction if the key stored in VX(only consider the lowest nibble) is not pressed (usually the next instruction is a jump to skip a code block)
                        const x = (self.opcode & 0x0F00) >> 8; 
                        if (!self.key[@as(u4, @truncate(self.V[x]))]) {
                            // print("skipped not pressed, val : {any}\n", .{@as(u4, @truncate(self.V[x]))});
                            self.pc += 2;
                        }
                    },
                    0x000E => { // EX9E if (key() == Vx)	Skips the next instruction if the key stored in VX(only consider the lowest nibble) is pressed (usually the next instruction is a jump to skip a code block)
                        const x = (self.opcode & 0x0F00) >> 8;
                        if (self.key[@as(u4, @truncate(self.V[x]))]) {
                            // print("skipped pressed, val : {any}\n", .{@as(u4, @truncate(self.V[x]))});
                            self.pc += 2;
                        }
                    },
                    else => {
                        print("Opcode 0xE___: 0x{x} not handled\n", .{self.opcode});
                        return error.OpcodeNotDecoded;
                    },
                }
            },
            0xF000 => {
                switch (self.opcode & 0x00FF) {
                    0x0007 => { // FX07 Sets VX to the value of the delay timer.
                        const x = (self.opcode & 0x0F00) >> 8;
                        self.V[x] = self.delay_timer.time;
                    },
                    0x000A => { // FX0A A key press is awaited, and then stored in VX (blocking operation, all instruction halted until next key event, delay and sound timers should continue processing)
                        const x = (self.opcode & 0xF00) >> 8;
                        var found = false;
                        for (self.key, 0..) |k, i| {
                            if (k){
                                found = true;
                                self.V[x] = @intCast(i);
                                break;
                            }
                        } 
                        if (!found) {
                            self.pc -= 2;
                        }
                    },
                    0x0015 => { // FX15 Sets the delay timer to VX
                        const x = (self.opcode & 0xF00) >> 8;
                        self.delay_timer.time = self.V[x];
                    },
                    0x0018 => { // FX18 Sets the sound timer to VX.
                        const x = (self.opcode & 0xF00) >> 8;
                        self.delay_timer.time = self.V[x];
                    },
                    0x001E => { // Adds VX to I. VF is not affected
                        const x = (self.opcode & 0xF00) >> 8;
                        self.I += self.V[x];
                    },
                    0x0029 => { // FX29 Sets I to the location of the sprite for the character in VX(only consider the lowest nibble). Characters 0-F (in hexadecimal) are represented by a 4x5 font
                        const x = (self.opcode & 0xF00) >> 8;
                        self.I = self.memory[ @as(u8, @truncate(self.V[x]))*5];
                    },
                    0x0033 => { // FX33 Stores the binary-coded decimal representation of VX, with the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2
                        const x = (self.opcode & 0xF00) >> 8;
                        // print("V[x]: {d}, I: 0x{X}\t", .{self.V[x], self.I});     
                        self.memory[self.I] = self.V[x] / 100;
                        self.memory[self.I + 1] = (self.V[x] / 10) % 10;
                        self.memory[self.I + 2] = self.V[x] % 10;
                        // print(" {d}{d}{d}\n", .{self.memory[self.I], self.memory[self.I+1], self.memory[self.I+2]});
                    },
                    0x0055 => { // Stores from V0 to VX (including VX) in memory, starting at address I. The offset from I is increased by 1 for each value written, but I itself is left unmodified
                        const x = (self.opcode & 0xF00) >> 8;
                        var i: u5 = 0;
                        while(i <= x) {
                            self.memory[self.I + i] = self.V[i];
                            i+=1;
                        }
                    },
                    0x0065 => { // FX65 Fills from V0 to VX (including VX) with values from memory, starting at address I. The offset from I is increased by 1 for each value read, but I itself is left unmodified.
                        const x = (self.opcode & 0xF00) >> 8;
                        var i: u5 = 0;
                        while(i <= x) {
                            // print("int overflow? {d}\n", .{i});
                            self.V[i] = self.memory[self.I + i];
                            i+=1;
                        }
                    },
                    else => {
                        print("Opcode 0xF___: 0x{x} not handled", .{self.opcode});
                        return error.OpcodeNotDecoded;
                    },
                }
            },
            else => {
                print("Uninitialized, or invalid opcode: 0x{x}\n", .{self.opcode});
                return error.OpcodeNotDecoded;
            },
        }
        //update timers TODO: Update at 60hz
        if (self.delay_timer.time > 0)
            self.delay_timer.countdown();
        if (self.sound_timer.time > 0) {
            if (self.sound_timer.time == 1)
                print("BEEP!\n", .{});
            self.sound_timer.countdown();
        }
    }
};

fn getKeyvalueFromKeycode(keycode: c_uint) isize {
    for (0..16) |i| {
        const mapping = keymap[@as(u4, @truncate(i))];
        const key = mapping[0];
        const value = mapping[1];
        if (key == keycode) {
            return @as(isize, value);
        }
    }
    return 16;
}

fn getCharFromKeycode(keyvalue: c_uint) *const [1:0]u8 {
     for (0..16) |i| {
        const mapping = keymap[@as(u4, @truncate(i))];
        const key = mapping[1];
        const char = mapping[2];
        if (key == keyvalue) {
            return char;
        }
    }
    return " ";
}

fn getKeycodeFromKeyvalue(keyvalue: u4) c_uint {
    for (0..16) |i| {
        const mapping = keymap[@as(u4, @truncate(i))];
        const key = mapping[0];
        const value = mapping[1];
        if (value == keyvalue) {
            return key;
        }
    }
    return 16;
}
fn getEvents(cpu: *CPU) !void {
    // var cpu = cpuPtr.*;
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_RETURN => {
                        print("enter key down\n", .{});
                        cpu.init();
                        try cpu.reload();
                    },
                    else => {
                        const keycode = event.key.key;
                        const mapping = getKeyvalueFromKeycode(keycode);
                        print("Down: key: {d}, mapping: {d}\n", .{ keycode, mapping });
                        if (mapping < 16) {
                            cpu.key[@intCast(mapping)] = true;
                        }
                        print("keymap | {any}\n", .{cpu.key}); //true here
                    }
                }
            },
            c.SDL_EVENT_KEY_UP => {
                const keycode = event.key.key;
                const mapping = getKeyvalueFromKeycode(keycode);
                print("Up: key: {d}, mapping: {d}\n", .{ keycode, mapping });
                if (mapping < 16) {
                    cpu.key[@intCast(mapping)] = false;
                }
                print("keymap | {any}\n", .{cpu.key});
            },
            c.SDL_EVENT_QUIT => {
                running = false;
            },
            else => {},
        }
    }
}

var running = true;
pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        print("SDL_Init failed: {s}\n", .{c.SDL_GetError()});
        return error.InitializationFailed;
    }
    defer c.SDL_Quit();

    var win: ?*c.SDL_Window = null;
    var renderer: ?*c.SDL_Renderer = null;
    if (!c.SDL_CreateWindowAndRenderer("chip8", gfxWidth * cellSize, gfxHeight * cellSize, 0, &win, &renderer)) {
        print("Failed to create window or renderer: {s}\n", .{c.SDL_GetError()});
        return;
    }
    if (win == null) {
        print("Failed to create window: {s}\n", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_DestroyWindow(win);
    if (renderer == null) {
        print("Failed to create renderer: {s}\n", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_DestroyRenderer(renderer);
    const IBM = "roms/IBM_Logo.ch8";
    const testRom = "roms/test_opcode.ch8";
    const BC = "roms/BC_test.ch8";
    const flags = "roms/4-flags.ch8";
    const logo2 = "roms/2-ibm-logo.ch8";
    const betterTest = "roms/3-corax+.ch8";
    const keypad = "roms/6-keypad.ch8";
    const game = "roms/games/Most Dangerous Game [Peter Maruhnic].ch8";

    _ = keypad;
    // _ = game;
    _ = betterTest;
    _ = testRom;
    _ = IBM;
    _ = logo2;
    _ = BC;
    _ = flags;

    
    var cpu = CPU{};
    cpu.init();
    try cpu.loadExe(game); // load exe here
   
//    const nsPs = 1_000_000_000;
   const cycleFreq = 800;

   var frameCount: u64 = 0;
   var timerFPS: u64 = 0;
   var lastFrame: u64 = 0;
   var fps: u64 = 0;
   var lastTime: u64 = 0;
    // running = false;
    while (running) {    
        lastFrame = c.SDL_GetTicks();
        if (lastFrame>=(lastTime+1000)) {
            lastTime = lastFrame;
            fps = frameCount;
            frameCount = 0;
            print("Current FPS: {d}\n", .{fps});
        }
        try cpu.cycle();
        if (cpu.drawFlag) {
            //draw here
            _ = c.SDL_SetRenderDrawColor(renderer, 50, 0, 175, 10);
            _ = c.SDL_RenderClear(renderer);
            _ = c.SDL_SetRenderDrawColor(renderer, 120, 0, 255, 10);
            var cell = c.SDL_FRect{};
            for (0..gfxHeight) |y| {
                for (0..gfxWidth) |x| {
                    const i = x + y * 64;
                    cell.x = @floatFromInt(x * cellSize);
                    cell.y = @floatFromInt(y * cellSize);
                    cell.h = cellSize;
                    cell.w = cellSize;
                    if (cpu.gfx[i] == 1) {
                        if (!c.SDL_RenderFillRect(renderer, &cell)) {
                            print("SDL_RenderFillRect failed: {s}\n", .{c.SDL_GetError()});
                        }
                    }
                }
            }
            _ = c.SDL_RenderPresent(renderer);
            cpu.drawFlag = false;
        }   
        frameCount+=1;
        timerFPS = c.SDL_GetTicks() - lastFrame;
        if (timerFPS<(1000/cycleFreq)) {
            c.SDL_Delay(@intCast((1000/cycleFreq) - timerFPS));
        }     
        try getEvents(&cpu);  
    }
}