// Count the number of primes in the range 0-100000
pub fn main() -> i32 {
  let mut primes: i32 = 0;
  let mut range: i32 = 100000;
  while range > 1 {
    let mut j: i32 = 2;
    let mut is_prime: bool = true;
    while j < range {
      if range % j == 0 {
        is_prime = false;
        break;
      }
      j = j + 1;
    }
    if is_prime {
      primes = primes + 1;
    }
    range = range - 1;
  }
  primes
}
