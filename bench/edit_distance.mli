open! Base

module Seq : sig
  val dist : string -> string -> int
end

module Par : sig
  val dist : num_domains:int -> string -> string -> int
end
