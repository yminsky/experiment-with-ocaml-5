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
      | Distance of Seq_or_par.t * string * string
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
       match benchmark with
       | Distance (seq_or_par, a, b) ->
         (match seq_or_par with
          | Seq -> printf "%d\n" (Edit_distance.Seq.dist a b : int)
          | Par -> printf "%d\n" (Edit_distance.Par.dist ~num_domains a b : int))
       | Fib (Seq, n) -> printf "%d\n" (Fib.Seq.fib n)
       | Fib (Par, n) -> printf "%d\n" (Fib.Par.fib ~num_domains n))
  |> Command_unix.run
;;
