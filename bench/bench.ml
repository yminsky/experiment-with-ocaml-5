open! Core

module Benchmark_id = struct
  module Seq_or_par = struct
    type t =
      | Seq
      | Par
    [@@deriving sexp]
  end

  module T = struct
    type t = Distance of Seq_or_par.t * string * string [@@deriving sexp]
  end

  include T
  include Sexpable.To_stringable (T)
end

module Sequential = struct
  let rec edit_distance s t =
    match String.length s, String.length t with
    | 0, x | x, 0 -> x
    | len_s, len_t ->
      let s' = String.drop_suffix s 1 in
      let t' = String.drop_suffix t 1 in
      let cost_to_drop_both =
        if Char.( = ) s.[len_s - 1] t.[len_t - 1] then 0 else 1
      in
      let d1 = edit_distance s' t + 1 in
      let d2 = edit_distance s t' + 1 in
      let d3 = edit_distance s' t' + cost_to_drop_both in
      let ( ++ ) = Int.min in
      d1 ++ d2 ++ d3
  ;;
end

module Parallel = struct
  module Task = Domainslib.Task

  let rec edit_distance pool s t =
    match String.length s, String.length t with
    | 0, x | x, 0 -> x
    | len_s, len_t ->
      let s' = String.drop_suffix s 1 in
      let t' = String.drop_suffix t 1 in
      let cost_to_drop_both =
        if Char.( = ) s.[len_s - 1] t.[len_t - 1] then 0 else 1
      in
      let async f = Task.async pool f in
      let d1 = async (fun () -> edit_distance pool s' t + 1) in
      let d2 = async (fun () -> edit_distance pool s t' + 1) in
      let d3 = async (fun () -> edit_distance pool s' t' + cost_to_drop_both) in
      let ( ++ ) = Int.min in
      Task.await pool d1 ++ Task.await pool d2 ++ Task.await pool d3
  ;;

  let edit_distance ~num_domains s t =
    let pool = Task.setup_pool ~num_domains () in
    let res = Task.run pool (fun () -> edit_distance pool s t) in
    Task.teardown_pool pool;
    res
  ;;
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
       match benchmark with
       | Distance (seq_or_par, a, b) ->
         (match seq_or_par with
          | Seq -> printf "%d\n" (Sequential.edit_distance a b : int)
          | Par -> printf "%d\n" (Parallel.edit_distance ~num_domains a b : int)))
  |> Command_unix.run
;;
