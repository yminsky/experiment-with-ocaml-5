open! Core

module Benchmark_id = struct
  module Seq_or_par = struct
    type t =
      | Seq
      | Par
    [@@deriving sexp]
  end

  module T = struct
    type t =
      | Dist of Seq_or_par.t * string * string
      | Memo_dist of string * string
      | Fib of Seq_or_par.t * int
    [@@deriving sexp]
  end

  include T
  include Sexpable.To_stringable (T)
end

let () =
  Command.basic
    ~summary:"Benchmark a thing"
    (let%map_open.Command () = return ()
     and num_domains = anon ("domains" %: int)
     and benchmark =
       anon ("benchmark" %: Command.Arg_type.create Benchmark_id.of_string)
     in
     fun () ->
       (* parallel scheduler takes a single domain automatically *)
       let num_domains = num_domains - 1 in
       let res =
         match benchmark with
         | Dist (Seq, a, b) -> Edit_distance.Seq.dist a b
         | Dist (Par, a, b) -> Edit_distance.Par.dist ~num_domains a b
         | Memo_dist (a, b) -> Edit_distance.Seq_memo.dist a b
         | Fib (Seq, n) -> Fib.Seq.fib n
         | Fib (Par, n) -> Fib.Par.fib ~num_domains n
       in
       printf "%d\n" res)
  |> Command_unix.run
;;
