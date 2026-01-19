const common = @import("./common.zig");
const truncf = @import("./truncf.zig").truncf;

comptime {
    if (common.want_ppc_abi) {
        @export(&__trunctfhf2, .{ .name = "__trunckfhf2", .linkage = common.linkage, .visibility = common.visibility });
    }
    @export(&__trunctfhf2, .{ .name = "__trunctfhf2", .linkage = common.linkage, .visibility = common.visibility });
}

pub fn __trunctfhf2(a: f128) callconv(.c) common.F16T(f128) {
    return @bitCast(truncf(f16, f128, a));
}
