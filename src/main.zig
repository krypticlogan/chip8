const std = @import("std");
// const SDL = @import("sdl_lib");
// const SDL = @cImport({
//     @cDefine("SDL_DISABLE_OLD_NAMES", {});
//     @cInclude("..SDL3/SDL.h");
//     @cInclude("SDL3/SDL_revision.h");
//     @cDefine("SDL_MAIN_HANDLED", {});
//     @cInclude("SDL3/SDL_main.h");
// });
const SDL = @cImport({
    @cInclude("SDL");
    });
// SDL.
// const importing = @import("fjvsnvd");
// sdl.
const print = std.debug.print;

const FONTSET =  [_]u8{
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
0xF0, 0x80, 0xF0, 0x80, 0x80  // F
};
const timer = struct{
    time: u8 = undefined,

    fn init(self: *@This(), time: u8) void {
        self.time = time;
    }

    fn countdown(self: *@This()) void {
        self.time-=1;
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
    gfx: [64*32]u2 = undefined,

    //timers
    delay_timer: timer = timer{},
    sound_timer: timer = timer{},

    ///program stack
    stack: [16]u12 = undefined,
    ///stack pointer
    sp: u5 = undefined,

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
        
        //reset values
        self.pc = 0;
        self.I = 0;
        self.sp = 0;
        self.opcode = 0;

        //Load fontset
        for(0..FONTSET.len) |i|{
            self.memory[i] = FONTSET[i];
        }
}
    // /Loads a chip-8 file
    fn load(self: *@This(), file: []u8) void {
        for (0..file.len)|i|{
            self.memory[i+0x200] = file[i];
        }
    }

    pub fn cycle() void {
        //fetch

        //decode

        //execute

        //update timers
    }
};

pub fn main() !void {
    if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO) != false) {
        std.debug.print("SDL_Init failed: {s}\n", .{SDL.SDL_GetError()});
        return error.InitializationFailed;
    }
    // ... rest of your code ...
    defer SDL.SDL_Quit();
    
    var cpu = CPU{};
    cpu.init();
    print("memory: {any}", .{cpu.memory});
}