import std/setutils, strutils, hashes, tables, strformat

type StreamSlice* = object
  source: ref string
  start: int
  finish: int

type ParseError* = object of ValueError
  line*: int

const IDENTIFIER_FIRST = setutils.toSet("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
const IDENTIFIER_NEXT  = setutils.toSet("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.")
const NUMBER_FIRST = setutils.toSet("0123456789-+")
const NUMBER_NEXT  = setutils.toSet("0123456789")
const QUOTES* = {'"', '\'', '`'}

func new_StreamSlice*(source: string): StreamSlice =
  var reference = new(string)
  reference[] = source
  return StreamSlice(
    source: reference,
    start: 0,
    finish: source.len,
  )

func empty_slice(s: StreamSlice): StreamSlice =
  result = s
  result.finish = s.start

func finished*(s: StreamSlice): bool =
  assert not isNil(s.source)
  return s.start >= s.finish

func len*(s: StreamSlice): int =
  assert not isNil(s.source)
  return s.finish - s.start

func `$`*(s: StreamSlice): string =
  assert not isNil(s.source)
  return s.source[s.start..s.finish - 1]

func `[]`*(s: StreamSlice, index: int): char =
  assert not isNil(s.source)
  return s.source[s.start + index]

func `[]`*(s: StreamSlice, index: BackwardsIndex): char =
  assert not isNil(s.source)
  let i = s.finish - index.int
  if i < 0: return
  return s.source[i]

func `[]`*(s: StreamSlice, index: HSlice): StreamSlice =
  assert not isNil(s.source)
  result = s
  result.start  += index.a
  result.finish -= index.b.int - 1

func get_index*(s: StreamSlice): int =
  assert not isNil(s.source)
  return s.start

func set_index*(s: var StreamSlice, value: int) =
  assert not isNil(s.source)
  s.start = value

func get_slice*(s: StreamSlice, start: int, finish: int): StreamSlice =
  result = s
  result.start = start
  result.finish = finish

func get_string*(s: StreamSlice, start: int, finish: int): string =
  return $s.source[start..finish - 1]

func dbg*(s: StreamSlice): string =
  return s.source[0..s.start - 1] & "\u001b[31m" & s.source[s.start..s.finish - 1] & "\u001b[0m" & s.source[s.finish..^1]

type TokenKind* = enum
  tk_none # Will be skipped by `add_token`
  tk_unknown # Will not be skipped by `add_token`, use for e.g. unknown characters
  tk_whitespace
  tk_comment
  tk_text # Generic text, i.e. descriptions

  tk_number
  tk_string
  tk_operator # '+', '-', '/', ...
  tk_seperator # ',', ':', ...
  tk_bracket

  tk_identifier # Generated by the parsing functions, should normally be replaced
  tk_mnenomic
  tk_directive
  tk_literal # false, true, big, little, ...
  tk_type_name # S64, immediate, custom field names
  tk_field_name # The names defined within custom fields
  tk_field_ref # %a, %some_name
  tk_register_1 # Normal register names
  tk_register_2 # Special register names (e.g. sp, ip)
  tk_register_3 # Control register names (e.g. control registers)
  tk_label
  tk_const

  tk_header # [settings], [fields], [instructions]

  # Control instructions
  tk_new_instruction

const CONTROL_TOKENS = {tk_new_instruction}

type Token* = object
  s*: StreamSlice
  tk*: TokenKind

type RestorePoint* = object
  s: StreamSlice
  token_count: int

var tracked_source: ref string = nil
var tokens: seq[Token]

func checkpoint*(s: StreamSlice): RestorePoint =
  {.noSideEffect.}:
    if s.source == tracked_source:
      return RestorePoint(s: s, token_count: tokens.len)
    else:
      return RestorePoint(s: s, token_count: -1)

func restore*(s: var StreamSlice, cp: RestorePoint) =
  {.noSideEffect.}:
    assert s.source == cp.s.source, "RestorePoint does not apply to this stream"
    assert (s.source == tracked_source) == (cp.token_count >= 0), "Token tracking status changed since this RestorePoint was created"
    assert cp.token_count <= tokens.len, "`restore` cannot recreate deleted tokens"
    s = cp.s
    tokens.set_len(cp.token_count)

func start_tokenize*(s: StreamSlice) =
  ## Starts tracking the tokens for this source, ignoring all others. Also clears the token list
  ## Can be called with 'nil' to stop tracking
  {.noSideEffect.}:
    tracked_source = s.source
    tokens.set_len(0)

func start_tokenize*(s: ref string) =
  ## Starts tracking the tokens for this source, ignoring all others. Also clears the token list
  ## Can be called with 'nil' to stop tracking
  {.noSideEffect.}:
    tracked_source = s
    tokens.set_len(0)

func collect_tokens*(s: StreamSlice, clean_out: bool = true): seq[Token] =
  {.noSideEffect.}:
    assert s.source == tracked_source, "collect_tokens called with incorrect StreamSlice"
    result = tokens
    if clean_out: tokens.set_len(0)

func add_token*(s: StreamSlice, tk: TokenKind) =
  ## Adds a token starting from the end of the last token to the start of s
  {.noSideEffect.}:
    if tk == tk_none:
      return

    if tracked_source != s.source:
      return

    let start = if tokens.len == 0:
        0
      else:
        tokens[^1].s.finish

    let finish = s.start

    if tk in CONTROL_TOKENS:
      assert start == finish
      tokens.add Token(s: StreamSlice(source: s.source, start: start, finish: finish), tk: tk)
      return

    if start == finish: # Token would be zero length, don't generate it at all
      return
    assert finish > start, &"Invalid call to add_token, forgot to restore properly? (start={start}, finish={finish})"
    if tokens.len > 0 and tokens[^1].tk == tk:
      tokens[^1].s.finish = finish
    else:
      tokens.add Token(s: StreamSlice(source: s.source, start: start, finish: finish), tk: tk)

func change_token_kind*(expected: TokenKind, new: TokenKind) =
  {.noSideEffect.}:
    assert tokens[^1].tk == expected
    tokens[^1].tk = new

func peek*(s: StreamSlice): char =
  assert not isNil(s.source)
  if s.start >= s.finish: return
  return s.source[s.start]

func peek*(s: StreamSlice, offset: int): char =
  assert not isNil(s.source)
  let i = s.start + offset
  if i > s.source[].high: return
  return s.source[i]

func skip*(s: var StreamSlice, amount = 1, tk=tk_none) =
  assert not isNil(s.source)
  s.start += amount
  add_token(s, tk)

func read*(s: var StreamSlice, tk=tk_none): char =
  assert not isNil(s.source)
  if s.start > s.source[].high: return
  result = s.source[s.start]
  s.start += 1
  add_token(s, tk)

func matches*(s: var StreamSlice, value: string, increment = true, tk = tk_none): bool =
  for i in 0..value.high:
    if peek(s, i) != value[i]:
      return false
  if increment:
    s.start += value.len
    add_token(s, tk)
  return true

func matches*(s: var StreamSlice, value: char, tk=tk_none): bool =
  if peek(s) == value:
    s.start += 1
    add_token(s, tk)
    return true

func skip_comment*(s: var StreamSlice, line_comments = @[";", "//"], block_comments = @{"/*": "*/"}): bool =
  for (start_sym, end_sym) in block_comments:
    if s.matches(start_sym):
      while not finished(s) and not s.matches(end_sym):
        s.start += 1
      add_token(s, tk_comment)
      return true
  for lc in line_comments:
    if s.matches(lc):
      while not finished(s) and peek(s) != '\n':
        s.start += 1
      add_token(s, tk_comment)
      return true

func skip_whitespaces*(s: var StreamSlice, line_comments = @[";", "//"], block_comments = @{"/*": "*/"}) =
  while peek(s) in {' ', '\t', '\r'}:
    s.start += 1
  add_token(s, tk_whitespace)
  if skip_comment(s, line_comments, block_comments):
    skip_whitespaces(s)

func skip_newlines*(s: var StreamSlice, line_comments = @[";", "//"], block_comments = @{"/*": "*/"}): bool {.discardable.} =
  var any_newline = false
  while peek(s) in {' ', '\r', '\n', '\t'}:
    if read(s) == '\n':
      any_newline = true
  add_token(s, tk_whitespace)
  if skip_comment(s, line_comments, block_comments):
    skip_newlines(s) or any_newline
  else:
    any_newline or finished(s) # If we are at the end of the file, act as if we had an infinite stream of newlines

template on_err*[T](inp: (string, T), callback: untyped): T =
  let (raw_err, res) = inp
  if raw_err != "":
    let err {.inject, used.} = raw_err
    callback
  else:
    res

func get_identifier*(s: var StreamSlice, tk=tk_identifier): StreamSlice =
  result = s
  result.finish = s.start

  if peek(s) notin IDENTIFIER_FIRST:
    return

  skip(s)
  result.finish += 1

  while peek(s) in IDENTIFIER_NEXT:
    skip(s)
    result.finish += 1
  add_token(s, tk)

func get_unsigned*(s: var StreamSlice): (string, StreamSlice) =
  result[1] = s
  result[1].finish = s.start
  if peek(s) == '0':
    if peek(s, 1) == 'x':
      skip(s, 2)
      result[1].finish += 2
      while peek(s) in setutils.toSet("0123456789abcdefABCDEF"):
        skip(s)
        result[1].finish += 1
      add_token(s, tk_number)
      return result
    if peek(s, 1) == 'o':
      skip(s, 2)
      result[1].finish += 2
      while peek(s) in setutils.toSet("01234567"):
        skip(s)
        result[1].finish += 1
      add_token(s, tk_number)
      return result
    if peek(s, 1) == 'b':
      skip(s, 2)
      result[1].finish += 2
      while peek(s) in setutils.toSet("01"):
        skip(s)
        result[1].finish += 1
      add_token(s, tk_number)
      return result

  if peek(s) notin NUMBER_FIRST:
    return ("Expected a number literal", empty_slice(s))
  skip(s)
  result[1].finish += 1
  while peek(s) in NUMBER_NEXT:
    skip(s)
    result[1].finish += 1
  add_token(s, tk_number)

func xdigit_to_value(c: char): int =
  # Assumes that c has already been verified
  if c in DIGITS:
    return c.ord - '0'.ord
  if c in {'A'..'Z'}:
    return c.ord - 'A'.ord + 10
  return c.ord - 'a'.ord + 10

func parse_unsigned*(s: StreamSlice): (string, uint64) =
  # TODO: Generate more correct error messages in this function and probably don't use the builtin functions
  if s.len < 3: 
    try:
      return ("", cast[uint64](parseInt($s)))
    except ValueError: return ("Invalid int literal", 0'u64)
  try:
    case s[1]:
      of 'x': return ("", fromHex[uint64]($s))
      of 'o': return ("", fromOct[uint64]($s))
      of 'b': return ("", fromBin[uint64]($s))
      else:   return ("", cast[uint64](parseInt($s)))
  except ValueError: return ("Invalid int literal", 0'u64)

func get_signed*(s: var StreamSlice): (string, StreamSlice) =
  
  let negative = s.peek() == '-'
  if negative:
    skip(s)
  # The sign will be implictly included by the call to add_token in get_unsigned
  result = s.get_unsigned()
  if negative and result[0] == "":
    result[1].start -= 1

func parse_signed*(s: StreamSlice): (string, int) =
  if s.len == 0: return ("Invalid signed int literal", 0)

  if s[0] == '-':
    let raw_uint = parse_unsigned(s[1..^1]).on_err do:
      return (err, 0)
    if raw_uint > int.high.uint64 + 1: # we can represent one more negative value than positive values
      return ("Literal to large for a signed int", 0)
    return ("", -1 * cast[int](raw_uint))
  else:
    let raw_uint = parse_unsigned(s).on_err do:
      return (err, 0)
    if raw_uint > int.high.uint64:
      return ("Literal to large for a signed int", 0)
    return ("", cast[int](raw_uint))

func get_line_number*(s: StreamSlice): int =
  var line = 1
  for i in 0..s.start - 1:
    if s.source[i] == '\n':
      line += 1
  return line

func newParseError(s: StreamSlice, msg: string): ref ParseError =
  (ref ParseError)(msg: msg, parent: nil, line: get_line_number(s))

func `?`*[T](input: (string, T)): T =
  if input[0] != "":
    raise newException(ParseError, input[0])
  return input[1]

func `?`*(input: (string, StreamSlice)): StreamSlice =
  if input[0] != "":
    raise newException(ParseError, "Line " & $get_line_number(input[1]) & ": " & input[0])
  return input[1]

func get_size*(s: var StreamSlice): (string, int) =
  let cp = checkpoint(s)
  if peek(s) != '<' or peek(s, 1) != 'U':
    return ("Expected a size declaration here", 0)
  s.skip(2)
  let number = (get_unsigned(s).on_err do:
    return (err, 0)
  )
  if number.len == 0 or read(s) != '>':
    s.restore(cp)
    return ("Expected a size declaration here", 0)
  add_token(s, tk_type_name)
  return parse_signed(number)

iterator items*(s: StreamSlice): char =
  var i = s.start
  while i < s.finish:
    yield s.source[i]
    i += 1

iterator pairs*(s: StreamSlice): (int, char) =
  var i = s.start
  while i < s.finish:
    yield (i - s.start, s.source[i])
    i += 1

func `==`*(a: StreamSlice, b: StreamSlice): bool =
  if a.source == b.source and a.start == b.start and a.finish == b.finish: return true
  if a.len != b.len: return false
  for i, c in a:
    if b[i] != c: return false
  return true

func `==`*(a: StreamSlice, b: string): bool =
  if a.len != b.len: return false
  for i, c in a:
    if b[i] != c: return false
  return true

func `==`*(a: string, b: StreamSlice): bool =
  return b == a

func `&`*(a: StreamSlice, b: StreamSlice): StreamSlice =
  return new_StreamSlice($a & $b)

func `&`*(a: StreamSlice, b: string): StreamSlice =
  return new_StreamSlice($a & $b)

func `&`*(a: string, b: StreamSlice): StreamSlice =
  return new_StreamSlice($a & $b)

func hash*(s: StreamSlice): Hash =
  # Needed for contexts to be keys in maps
  var h: Hash = 0
  for c in s:
    h = h !& hash(c)
  result = !$h  

func get_enum*[T](s: var StreamSlice, options: openArray[(string, T)], tk=tk_identifier): (string, T) =
  for (str, value) in options:
    if s.matches(str, tk=tk):
      return ("", value)

  var joined_options = ""
  for i, (str, _) in options:
    if i != 0: # Not the first element
      if i == options.high: # This is the last element
        joined_options &= " or "
      else:
        joined_options &= ", "
    joined_options &= str
  let current = get_identifier(s, tk=tk)
  if current.len != 0:
    return ("Expected one of " & joined_options & ", got " & $current, default(T))
  else:
    return ("Expected one of " & joined_options, default(T))

func find*(s: var StreamSlice, candidates: openArray[string], tk=tk_none): int =
  for i, candidate in candidates:
    if matches(s, candidate, tk=tk):
      return i
  return -1

func find*(s: var StreamSlice, candidates: openArray[char], tk=tk_none): int =
  for i, candidate in candidates:
    if matches(s, candidate, tk=tk):
      return i
  return -1

func get_bool*(s: var StreamSlice): (string, bool) =
  let index = find(s, ["false", "true"], tk=tk_literal)

  if index == -1:
    return ("Expected a bool here.", false)

  return ("", bool(index))

func get_string*(s: var StreamSlice, tk=tk_string): (string, StreamSlice) =
  
  let cp = s.checkpoint()

  let quote = s.read()

  if quote notin QUOTES:
    s.restore(cp)
    return ("Expected an opening quote (one of \", ' or `)", empty_slice(s))

  while peek(s) != quote:
    if read(s) == '\\':
      discard read(s)
    if finished(s):
      s.restore(cp)
      return ("Unexpected EOF while parsing a string", empty_slice(s))

  discard read(s)
  add_token(s, tk)
  result[1] = s
  result[1].start  = cp.s.start + 1
  result[1].finish = s.start - 1

func descape_string_content*(s: StreamSlice): (string, string) =
  var it = s
  while not it.finished():
    let c = it.read()
    if c != '\\':
      result[1].add c
      continue
    if it.finished():
      return ("Unfinished escape sequence", "")
    let nc = it.read()
    case nc:
      of 'a': result[1].add '\a' # Bell (Alert)
      of 'b': result[1].add '\b' # Backspace
      of 'f': result[1].add '\f' # Formfeed
      of 'n': result[1].add '\n' # Linefeed (newline)
      of 'r': result[1].add '\r' # Carriage Return
      of 't': result[1].add '\t' # Horizontal Tab
      of 'v': result[1].add '\v' # Vertical Tab
      of '\\': result[1].add '\\'
      of '"': result[1].add '"'
      of '\'': result[1].add '\''
      of '`': result[1].add '`'
      of '0'..'9':
        var value = nc.ord - '0'.ord
        if peek(it) in DIGITS:
          value = 8 * value + read(it).ord - '0'.ord
        if peek(it) in DIGITS:
          value = 8 * value + read(it).ord - '0'.ord
        if value > 255:
          return ("Invalid octal escape sequence", "")
        result[1].add char(value)
      of 'x':
        var digit1 = read(it)
        var digit2 = read(it)
        if digit1 not_in HEX_DIGITS or digit2 not_in HEX_DIGITS:
          return ("Invalid hex escape sequence", "")
        let value = xdigit_to_value(digit1) * 16 + xdigit_to_value(digit2)
        result[1].add char(value)
      else:
        return (&"Invalid escape character '{nc}'", "")

func make_escaped_string*(s: string, quote = '"'): string =
  result &= quote
  for c in s:
    if c in {quote, '\\'}:
      result &= "\\" & c
    if c in {'\x00'..'\x19'}:
      result &= "\\x" & toHex(c.ord, 2)
    else:
      result &= c
  result &= quote

func parse_string*(s: StreamSlice): (string, string) =
  # To be used with results from get_list_value
  var it = s
  let content = it.get_string().on_err do:
    return (err, "")
  return descape_string_content(content)


iterator get_encapsulation*(s: var StreamSlice, tk=tk_bracket): StreamSlice =
  assert not isNil(s.source)

  let cp = s.checkpoint()

  let open = read(s, tk)
  var close: char

  case open:
    of '(': close = ')'
    of '[': close = ']'
    of '{': close = '}'
    else:
      s.restore(cp) # TODO: Ideally we would not restore here (and in other places where we raise) I think, but that's a behavior change for later
      raise newParseError(s, &"Expected an opening parantheses (one of '(', '[' or '{{'), got '{open}'")

  skip_newlines(s)
  var inner = s

  var depth = 1
  while true:
    let c = read(s)
    if c == open:
      depth += 1
    elif c == close:
      depth -= 1
      if depth == 0: break
    elif c in QUOTES:
      s.start -= 1
      discard get_string(s, tk_none).on_err do:
        s.restore(cp)
        raise newParseError(s, err)
    elif finished(s):
      s.restore(cp)
      raise newParseError(s, "Expected '" & close & "', got EOF")

  inner.finish = s.start - 1
  yield inner
  add_token(s, tk)

proc skip_encapsulation*(s: var StreamSlice) =
  for _ in get_encapsulation(s):
    discard

func strip*(s: StreamSlice): StreamSlice {.deprecated: "For better token production, manually use skip_whitespaces/skip_newlines"}=
  result = s
  while peek(result) in {' ', '\t', '\r', '\n'}:
    skip(result)
  while result.finish - 1 > 0 and result.source[][result.finish - 1] in {' ', '\t', '\r', '\n'}:
    result.finish -= 1

func from_line_start*(s: StreamSlice): StreamSlice =
  result = s
  # Go back one if we are at a newline
  if result.start > 0 and peek(result) == '\n':
    result.start -= 1
  
  # Seek backwards until the start of the line
  while result.start > 0 and peek(result) != '\n':
    result.start -= 1
  
  # Go forwards from the start of that line to the end
  result.start += 1
  result.finish = result.start
  while result.finish < s.len and result.source[result.finish] != '\n':
    result.finish += 1

func get_list_value(s: var StreamSlice): (string, StreamSlice) =
  # This function is not allowed to call add_token with tk!=tk_none
  assert not isNil(s.source)

  let start = s.start

  case peek(s):
    of QUOTES: # These may contain commas
      discard get_string(s, tk=tk_none).on_err do:
        return (err, empty_slice(s))
    of '(', '[', '{': # These may contain commas
      skip_encapsulation(s)
    else:
      while peek(s) notin {',', ':', ' ', '\r', '\n', '\t', '\0'}:
        skip(s)

  result[1] = s
  result[1].start = start
  result[1].finish = s.start
  result[1] = result[1]

iterator get_list*(s: var StreamSlice): StreamSlice =

  let restore = s
  for raw_inner in get_encapsulation(s):
    var list = raw_inner
    while not finished(list):
      skip_newlines(list)

      let start = list.start
      let element = get_list_value(list).on_err do:
        s = restore
        raise newParseError(s, err)
      if list.start == start:
        s = restore
        raise newParseError(s, "Expecated a list value")

      yield element

      skip_newlines(list)

      if peek(list) == ',':
        skip(list, tk=tk_seperator)
        skip_newlines(list)

proc get_whole_list*(s: var StreamSlice): seq[StreamSlice] =
  for value in get_list(s):
    result.add(value)

iterator get_table*(s: var StreamSlice): (bool, StreamSlice) =
  ## yields (is_value, text). Will always generate a key followed by a value unless an exception is raised

  let restore = s
  for raw_inner in get_encapsulation(s):
    var list = raw_inner
    while not finished(list):
      skip_whitespaces(list)

      let key = get_list_value(list).on_err do:
        s = restore
        raise newParseError(s, err)
      if key.len == 0:
        s = restore
        raise newParseError(s, "Expected a key")
      yield (false, key)
      skip_whitespaces(list)

      if read(list, tk_seperator) != ':':
        s = restore
        raise newParseError(s, "Expected ':' after the key")
      skip_whitespaces(list)

      let value = get_list_value(list).on_err do:
        s = restore
        raise newParseError(s, err)

      if value.len == 0:
        s = restore
        raise newParseError(s, "Expected a value")

      yield (true, value)

      skip_whitespaces(list)
      if peek(list) == ',':
        skip(list, tk=tk_seperator)
        skip_newlines(list)
      elif not finished(list):
        s = restore
        raise newParseError(s, "Expected a ',' or end of table")

proc get_whole_table*(s: var StreamSlice): OrderedTable[StreamSlice, StreamSlice] =
  var key: StreamSlice

  for is_value, value in get_table(s):
    if not is_value:
      key = value
    else:
      result[key] = value

      