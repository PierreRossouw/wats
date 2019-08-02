export func $main() i32 {
  $fib(7)    ;; should return 13
}

func $fib($n i32) i32 {
  if $n > 1 {
    return $fib($n - 1) + $fib($n - 2) 
  }
  $n
}

