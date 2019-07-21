;; Count the number of primes in the range 0-100000
export func $main() i32 {
  local mut $primes i32 = 0
  local mut $range i32 = 100000
  
  loop { br_if $range <= 0 
    local mut $j i32 = 2
    local mut $is_prime i32 = 1
    loop { br_if $j >= $range 
      if $range % $j == 0 {
        $is_prime = 0
        br
      }
      $j += 1
    }
    $primes += $is_prime
    $range -= 1
  }
  
  $primes
}
