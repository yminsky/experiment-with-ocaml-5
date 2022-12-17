open! Base

module Seq = struct
  let rec dist s t =
    match String.length s, String.length t with
    | 0, x | x, 0 -> x
    | len_s, len_t ->
      let s' = String.drop_suffix s 1 in
      let t' = String.drop_suffix t 1 in
      let cost_to_drop_both =
        if Char.( = ) s.[len_s - 1] t.[len_t - 1] then 0 else 1
      in
      let d1 = dist s' t + 1 in
      let d2 = dist s t' + 1 in
      let d3 = dist s' t' + cost_to_drop_both in
      let ( ++ ) = Int.min in
      d1 ++ d2 ++ d3
  ;;
end

module Par = struct
  module Task = Domainslib.Task

  let rec dist pool s t =
    let async f = Task.async pool f in
    let await x = Task.await pool x in
    match String.length s, String.length t with
    | 0, x | x, 0 -> x
    | len_s, len_t ->
      let s' = String.drop_suffix s 1 in
      let t' = String.drop_suffix t 1 in
      let cost_to_drop_both =
        if Char.( = ) s.[len_s - 1] t.[len_t - 1] then 0 else 1
      in
      let d1 = async (fun () -> dist pool s' t + 1) in
      let d2 = async (fun () -> dist pool s t' + 1) in
      let d3 = async (fun () -> dist pool s' t' + cost_to_drop_both) in
      let ( ++ ) = Int.min in
      await d1 ++ await d2 ++ await d3
  ;;

  let dist ~num_domains s t =
    let pool = Task.setup_pool ~num_domains () in
    let res = Task.run pool (fun () -> dist pool s t) in
    Task.teardown_pool pool;
    res
  ;;
end
