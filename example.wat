export func $main() i32 {
    $fib(7)        ;; should return 13
}

func $fib($n i32) i32 {
    i32.if $n > 1 {
        $fib($n - 1) + $fib($n - 2) 
    } else {
        $n
    }
}

;; Checks if a character is a digit / hex digit
;; $is_number('7', 0) -> 1
func $is_number($chr i32, $hexNum i32) i32 {
    if $chr >= '0' & $chr <= '9' {
        return 1
    } else if $hexNum {
        if ($chr >= 'a' & $chr <= 'f') | ($chr >= 'A' & $chr <= 'F') { 
            return 1
        }
    }
    0
}
