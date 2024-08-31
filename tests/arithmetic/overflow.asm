; This test currently functions more as a documentation of the current behavior
; It's expected results & error messages should be changed once parse_unsigned & parse_signed
; are properly (re-) implemented

loads64 0x5555555555555555
loadu64 0x5555555555555555
loadi64 0x5555555555555555

loads64 0xAAAAAAAAAAAAAAAB ; should error
loadu64 0xAAAAAAAAAAAAAAAB
loadi64 0xAAAAAAAAAAAAAAAB

; 6148914691236517205 == 0x5555555555555555
loads64 6148914691236517205
loadu64 6148914691236517205
loadi64 6148914691236517205

; -6148914691236517205 == 0xAAAAAAAAAAAAAAAB (mod 2^64)
loads64 -6148914691236517205
loadu64 -6148914691236517205 ; should error
loadi64 -6148914691236517205


loads64 0x8000000000000000  ; should error
loadu64 0x8000000000000000
loadi64 0x8000000000000000

loads64 0x7FFFFFFFFFFFFFFF
loadu64 0x7FFFFFFFFFFFFFFF
loadi64 0x7FFFFFFFFFFFFFFF

; 9223372036854775808 == 0x8000000000000000
;loads64 9223372036854775808 ; should error
;loadu64 9223372036854775808
;loadi64 9223372036854775808

; -9223372036854775808 == 9223372036854775808 == 0x8000000000000000 (mod 2^64)
loads64 -9223372036854775808
loadu64 -9223372036854775808  ; should error
loadi64 -9223372036854775808