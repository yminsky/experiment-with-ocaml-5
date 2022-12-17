open! Base

module Seq : sig
  val fib : int -> int
end

module Par : sig
  val fib : num_domains:int -> int -> int
end
