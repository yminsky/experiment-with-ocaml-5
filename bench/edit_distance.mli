open! Base

module Seq : sig
  val dist : string -> string -> int
end

module Par : sig
  val dist : num_domains:int -> string -> string -> int
end

module Seq_memo : sig
  val dist : string -> string -> int
  val dist_fixed_text : at_most:int -> int
end

module Par_memo : sig
  val dist : num_domains:int -> string -> string -> int
  val dist_fixed_text : num_domains:int -> at_most:int -> int
end
