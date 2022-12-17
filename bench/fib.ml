open! Base
module Task = Domainslib.Task

module Seq = struct
  let rec fib n =
    match n with
    | 0 | 1 -> 1
    | n -> fib (n - 1) + fib (n - 2)
  ;;
end

module Par = struct
  let rec fib pool n =
    if n < 20
    then Seq.fib n
    else (
      let async f = Task.async pool f in
      let await x = Task.await pool x in
      match n with
      | 0 | 1 -> 1
      | n ->
        let x1 = async (fun () -> fib pool (n - 1)) in
        let x2 = async (fun () -> fib pool (n - 2)) in
        await x1 + await x2)
  ;;

  let fib ~num_domains n =
    let pool = Task.setup_pool ~num_domains () in
    let res = Task.run pool (fun () -> fib pool n) in
    Task.teardown_pool pool;
    res
  ;;
end
