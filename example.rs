pub fn main() -> i32 {
  let primes: i32 = 0;
  let range: i32 = 100000;
  while range > 1 {
    let j: i32 = 2;
    let is_prime: bool = true
    while j < range {
      if range % j == 0 {
        is_prime = false;
        break;
      }
      j = j + 1;
    }
    if is_prime {
      numPrimes = numPrimes + 1;
    }
    range = range - 1;
  }
  primes
}
