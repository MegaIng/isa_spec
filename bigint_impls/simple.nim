import std/[bitops, algorithm, strutils]

type Digit = uint32
const DIGIT_WIDTH = 8 * sizeof(Digit)
const DIGIT_MASK = Digit.high.uint64
type SDigit = int32

func signbit(d: Digit): bool =
  d.testBit(BitsRange[Digit].high)

type BigInt* = object
  digits: seq[Digit] # digit order is little endian. We are using 2's complement. No unnesasrcy trailing 0 or Digit.high are allowed

type MathError* = object of ValueError

assert sizeof(BiggestUInt) == sizeof(uint64), "If this assert triggers, some of the constructor functions need to be updated to deal with int128"
assert sizeof(Digit) < sizeof(uint64), "Code currently assumes that Digit is smaller than uint64"

func sgn*(x: BigInt): int =
  ## returns -1, 0 or 1
  if x.digits.len == 0:
    return 0
  if x.digits[^1].signbit:
    return -1
  else:
    return 1

func fill_digit(x: BigInt): Digit =
  if x.sgn >= 0:
    return 0
  else:
    return Digit.high

func get_digit(x: BigInt, i: int): Digit =
  if i > x.digits.high:
    return x.fill_digit
  else:
    return x.digits[i]

when not defined(release):
  func check_valid(x: BigInt): BigInt {.discardable.} =
    if x.digits.len == 0:
      return
    if x.digits[^1] == 0:
      assert x.digits.len > 1, "Unnessarcy trailing 0"
      assert x.digits[^2].signbit, "Unnessarcy trailing 0"
    elif x.digits[^1] == Digit.high:
      if x.digits.len > 1:
        assert not x.digits[^2].signbit, "Unnessarcy trailing Digit.high"
    x
else:
  func check_valid(x: BigInt): BigInt {.discardable.} = x

func trim(x: var BigInt) =
  while x.digits.len > 0 and x.digits[^1] == 0:
    if x.digits.len == 1 or not x.digits[^2].signbit:
      x.digits.set_len(x.digits.len - 1)
    else:
      break
  while x.digits.len > 1 and x.digits[^1] == Digit.high:
    if x.digits[^2].signbit:
      x.digits.set_len(x.digits.len - 1)
    else:
      break


func toBigInt*(val: SomeUnsignedInt): BigInt =
  if val.uint64 > Digit.high.uint64:
    if val.test_bit(63):
      result.digits = @[Digit(val.uint64 and DIGIT_MASK), Digit(val shr DIGIT_WIDTH), 0]
    else:
      result.digits = @[Digit(val.uint64 and DIGIT_MASK), Digit(val shr DIGIT_WIDTH)]
  else:
    if val.test_bit(DIGIT_WIDTH - 1):
      result.digits = @[Digit(val.uint64), 0]
    else:
      result.digits = @[Digit(val.uint64)]
  result.check_valid()
  return result

func toBigInt*(val: SomeSignedInt): BigInt =
  if val.int64 > SDigit.high.int64 or val.int64 < SDigit.low.int64:
    result.digits = @[Digit(val.uint64 and DIGIT_MASK), Digit(val.int64 shr DIGIT_WIDTH)]
  elif val != 0:
    result.digits = @[Digit(val)]
  else:
    result.digits = @[]
  result.check_valid()

func slice_small*(x: BigInt; s: Slice[int]): BiggestUInt =
  assert s.len <= 8 * sizeof(BiggestUInt)
  assert s.a >= 0
  assert s.a <= s.b
  let first_digit = s.a div DIGIT_WIDTH
  let last_digit = s.b div DIGIT_WIDTH
  let fill = if x.sgn >= 0:
      0.BiggestUInt
    else:
      BiggestUInt.high
  for i in first_digit .. last_digit:
    let d = if i > x.digits.high:
        fill
      else:
        x.digits[i]
    let sub_start = max(s.a, i * DIGIT_WIDTH) - i * DIGIT_WIDTH
    let sub_end = min(s.b, (i + 1) * DIGIT_WIDTH - 1) - i * DIGIT_WIDTH
    let sec = d.bitsliced(sub_start .. sub_end)
    result = (result shl (sub_end - sub_start + 1)) or sec


func to_hex*(x: BigInt; len: Positive): string =
  for i in countdown(len - 1,  0):
      let hex_digit = x.slice_small((4*i) .. (4*i + 3))
      if hex_digit < 10:
        result &= char(ord('0') + hex_digit)
      else:
        result &= char(ord('A') + hex_digit - 10)

func hd_to_val(x: char): Digit =
  case x:
    of '0' .. '9':
      return (ord(x) - ord('0')).Digit
    of 'A' .. 'F':
      return (ord(x) - ord('A') + 10).Digit
    of 'a' .. 'f':
      return (ord(x) - ord('a') + 10).Digit
    else:
      raise newException(MathError, "Invalid hex digit '{" & x & "}'")

func parse_bigint_hex*(s: string): BigInt =
  if s.len == 0:
    return result.check_valid()
  var i = 0
  var j = 0
  var val: Digit
  for k in countdown(s.high, 0):
    if j > result.digits.high:
      result.digits.add 0
    val = hd_to_val(s[k])
    result.digits[j] = result.digits[j] or (val shl i)
    i += 4
    if i >= DIGIT_WIDTH:
      j += 1
      i = 0
  if val >= 8 and i != 0: # if i == 0, the last digit we added filled in the sign bit correctly
    result.digits[j] = result.digits[j] or (Digit.high shl i)
  result.trim()
  result.check_valid()


func highest_signficiant_bit*(x: BigInt): int =
  ## Returns the 0-based bit index of the first bit that is the same as all larger bits
  if x.digits.len == 0:
    return 0
  let offset = if x.digits[^1].signbit:
      if x.digits[^1] == Digit.high:
        0
      else:
        32 - countLeadingZeroBits(not x.digits[^1])
    else:
      if x.digits[^1] == 0:
        0
      else:
        32 - countLeadingZeroBits(x.digits[^1])
  return (x.digits.len - 1) * DIGIT_WIDTH + offset


func to_hex*(x: BigInt): string =
  x.to_hex((x.highest_signficiant_bit + 4) div 4)

func `not`*(x: BigInt): BigInt =
  result.digits.set_len(x.digits.len)
  for i, d in x.digits:
    result.digits[i] = not d
  if x.fill_digit == result.fill_digit:
    result.digits.add not x.fill_digit
  result.trim()
  result.check_valid()

func `and`*(x: BigInt, y: BigInt): BigInt =
  for i in 0 .. ( max(x.digits.high, y.digits.high)):
    result.digits.add x.get_digit(i) and y.get_digit(i)
  result.trim()
  result.check_valid()
func `or`*(x: BigInt, y: BigInt): BigInt =
  for i in 0 .. ( max(x.digits.high, y.digits.high)):
    result.digits.add x.get_digit(i) or y.get_digit(i)
  result.trim()
  result.check_valid()

func `xor`*(x: BigInt, y: BigInt): BigInt =
  for i in 0 .. ( max(x.digits.high, y.digits.high)):
    result.digits.add x.get_digit(i) xor y.get_digit(i)
  result.trim()
  result.check_valid()

func `+`*(x: BigInt, y: Digit): BigInt =
  var carry = y.uint64
  result = x
  if result.digits.len == 0:
    result.digits.add 0
  for i, d in result.digits:
    var val = d.uint64 + carry
    result.digits[i] = Digit(val and DIGIT_MASK)
    carry = val shr DIGIT_WIDTH
  let final = (x.fill_digit.uint64 + carry).Digit
  if final != result.fill_digit:
    result.digits.add final
  result.trim()
  result.check_valid()

func `+`(x: BigInt, y: BigInt): BigInt =
  var carry = 0'u64
  for i in 0 .. ( max(x.digits.len, y.digits.len) + 1):
    var val = x.get_digit(i).uint64 + y.get_digit(i).uint64 + carry
    result.digits.add Digit(val and DIGIT_MASK)
    carry = val shr DIGIT_WIDTH
  doAssert carry == 0 or carry == 1, $carry
  result.trim()
  result.check_valid()

func `-`*(x: BigInt): BigInt =
  result = (not x) + 1.Digit
  result.check_valid()

func abs*(x: BigInt): BigInt =
  if x.sgn >= 0:
    return x
  else:
    return -x

func `-`*(x: BigInt, y: BigInt): BigInt =
  return x + -y

func `-`*(x: BigInt, d: Digit): BigInt =
  return x + to_big_int(-(d.int64))

func `shl`*(x: BigInt, i: int): BigInt =
  let word_shift = i div DIGIT_WIDTH
  let subword_shift = i mod DIGIT_WIDTH
  if subword_shift != 0:
    var carry = 0.Digit
    for i in 0 .. x.digits.len + 1:
      result.digits.add carry or (x.get_digit(i) shl subword_shift)
      carry = x.get_digit(i) shr (DIGIT_WIDTH - subword_shift)
  else:
    result = x
  if word_shift != 0:
    let old_high = result.digits.high
    result.digits.set_len(result.digits.len + word_shift)
    for i in countdown(old_high, 0):
      result.digits[word_shift + i] = result.digits[i]
      result.digits[i] = 0
  result.trim()
  result.check_valid()

func `shr`*(x: BigInt, i: int): BigInt =
  let word_shift = i div DIGIT_WIDTH
  let subword_shift = i mod DIGIT_WIDTH
  if word_shift != 0:
    for i in 0 .. max(0, x.digits.len - word_shift):
      result.digits.add x.get_digit(word_shift + i)
  else:
    result = x
  if subword_shift != 0:
    var carry = x.fill_digit shl (DIGIT_WIDTH - subword_shift)
    for i in countdown(result.digits.high, 0):
      let d = result.digits[i]
      result.digits[i] = carry or (d shr subword_shift)
      carry = d shl (DIGIT_WIDTH - subword_shift)
  result.trim()
  result.check_valid()


func `*`*(x: BigInt, d: Digit): BigInt =
  for i in cast[set[BitsRange[Digit]]](d):
    result = result + (x shl i)

# func divmod(x: BigInt, d: Digit): (BigInt, Digit) =
#   var rem = x
#   while x.digits.len > 1:
#
#
# func to_dec(x: BigInt): string =
#   var current = x
#   let sign = if current.sgn < 0:
#       current = abs(current)
#       "-"
#     else:
#       ""
#   while current.sgn != 0:
#     let (new, rem) = divmod(current, 10)
#     result &= char(ord('0') + rem)
#     current = new
#   result &= sign
#   result.reverse()
