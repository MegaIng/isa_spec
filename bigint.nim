when defined(bigint_use_interned):
  include bigint_impls/with_interned
else:
  include bigint_impls/simple


when isMainModule:
  import std/[os, strutils]
  var args = command_line_params()
  if args.len == 0:
    quit(0)
  case args[0]:
  of "shell": # We provide a simple shell like system with a stack-like machine. Also used for fuzzing
    var stack: seq[BigInt]
    while true:
      stdout.write "> "
      stdout.flush_file()
      let cmd = stdin.readline().strip().split()
      if cmd.len == 0:
        continue
      case cmd[0]:
        of "quit":
          doAssert cmd.len == 1
          break
        of "help":
          doAssert cmd.len == 1
          for cmd in ["quit", "help", "b", "dup", "pop", "neg", "addu32", "add", "and", "or", "xor", "mulu32", "shli", "shlr"]:
            echo "- ", cmd
        of "b":
          doAssert cmd.len == 2
          stack.add parse_bigint_hex(cmd[1])
        of "dup":
          doAssert cmd.len == 1
          doAssert stack.len > 0
          stack.add stack[^1]
        of "pop":
          doAssert cmd.len == 1
          doAssert stack.len > 0
          discard stack.pop()
        of "neg":
          doAssert cmd.len == 1
          doAssert stack.len > 0
          stack.add -stack.pop()
        of "addu32":
          doAssert cmd.len == 2
          doAssert stack.len > 0
          let d = parse_biggest_uint(cmd[1]).uint32
          stack.add stack.pop() + d
        of "add":
          doAssert cmd.len == 1
          doAssert stack.len > 1
          let a = stack.pop()
          let b = stack.pop()
          stack.add a + b
        of "subu32":
          doAssert cmd.len == 2
          doAssert stack.len > 0
          let d = parse_biggest_uint(cmd[1]).uint32
          stack.add stack.pop() - d
        of "sub":
          doAssert cmd.len == 1
          doAssert stack.len > 1
          let a = stack.pop()
          let b = stack.pop()
          stack.add a - b
        of "and":
          doAssert cmd.len == 1
          doAssert stack.len > 1
          let a = stack.pop()
          let b = stack.pop()
          stack.add a and b
        of "or":
          doAssert cmd.len == 1
          doAssert stack.len > 1
          let a = stack.pop()
          let b = stack.pop()
          stack.add a or b
        of "xor":
          doAssert cmd.len == 1
          doAssert stack.len > 1
          let a = stack.pop()
          let b = stack.pop()
          stack.add a xor b
        of "mulu32":
          doAssert cmd.len == 2
          doAssert stack.len > 0
          let d = parse_biggest_uint(cmd[1]).uint32
          stack.add stack.pop() * d
        of "shli":
          doAssert cmd.len == 2
          doAssert stack.len > 0
          let i = parse_int(cmd[1]).int
          stack.add stack.pop() shl i
        of "shri":
          doAssert cmd.len == 2
          doAssert stack.len > 0
          let i = parse_int(cmd[1]).int
          stack.add stack.pop() shr i
        of "p":
          doAssert cmd.len == 1
          doAssert stack.len > 0
          echo stack[^1].to_hex()
        else:
          doAssert false, "Unknown command"
  else:
    doAssert false, "Unknown mode " & args[0]