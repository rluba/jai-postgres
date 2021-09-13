IS_BIG_ENDIAN :: #run big_endian();

big_endian :: () -> bool {
    x: s16 = 1;
    b := cast(*u8) *x;

    if b[0] return false;
    return true;
}

ntoh :: inline (value: $T) -> T {
	#if IS_BIG_ENDIAN {
		return value;
	} else {
		return byte_swap(value);
	}
}

hton :: ntoh;

#scope_file

#import "Basic";
#import "Compiler";
#import "Bit_Operations";

