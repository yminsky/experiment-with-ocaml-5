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
    | len_s, len_t when len_s + len_t < 12 -> Seq.dist s t
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

let long_s =
  "We hold these truths to be self-evident, that all men are created equal, \
   that they are endowed by their Creator with certain unalienable Rights, \
   that among these are Life, Liberty and the pursuit of Happiness.--That to \
   secure these rights, Governments are instituted among Men, deriving their \
   just powers from the consent of the governed, --That whenever any Form of \
   Government becomes destructive of these ends, it is the Right of the People \
   to alter or to abolish it, and to institute new Government, laying its \
   foundation on such principles and organizing its powers in such form, as to \
   them shall seem most likely to effect their Safety and Happiness. Prudence, \
   indeed, will dictate that Governments long established should not be \
   changed for light and transient causes; and accordingly all experience hath \
   shewn, that mankind are more disposed to suffer, while evils are \
   sufferable, than to right themselves by abolishing the forms to which they \
   are accustomed. But when a long train of abuses and usurpations, pursuing \
   invariably the same Object evinces a design to reduce them under absolute \
   Despotism, it is their right, it is their duty, to throw off such \
   Government, and to provide new Guards for their future security.--Such has \
   been the patient sufferance of these Colonies; and such is now the \
   necessity which constrains them to alter their former Systems of \
   Government. The history of the present King of Great Britain is a history \
   of repeated injuries and usurpations, all having in direct object the \
   establishment of an absolute Tyranny over these States. To prove this, let \
   Facts be submitted to a candid world."
;;

let long_t =
  "We hold these  truths to be self-evident, that all men are created equal, \
   that they are endowed by their Creator with certain unalienable Rights, \
   that among these are life, liberty and the pursuit of Happiness.--That to \
   secure these rights, Governments are instituted among Men, deriving their \
   just powers from the consent of the governed, --That whenever any Form of \
   Government becomes destructive of these ends, it is the Right of the People \
   to alter or to abolish it, and to institute new Government, laying its \
   foundation on such principles and organizing its powers in such form, as to \
   them shall seem most likely to effect their Safety and Happiness. Prudence, \
   indeed, will dictate that Governments long established should not be \
   changed for light and transient causes; and accordingly all experience hath \
   shewn, that mankind are more disposed to suffer, while evils are \
   sufferable, than to right themselves by abolishing the forms to which they \
   are accustomed. But when a long train of abuses and usurpations, pursuing \
   invariably the same Object evinces a design to reduce them under absolute \
   Despotism, it is their RIGHT, it is their DUTY, to throw off such \
   Government, and to provide new Guards for their future security.--Such has \
   been the patient sufferance of these Colonies; and such is now the \
   necessity which constrains them to alter their former Systems of \
   Government. The history of the King of Great Britain is a history of \
   repeated injuries and usurpations, all having in direct object the \
   establishment of an absolute Tyranny over these States. To prove this, let \
   Facts be submitted to a candid world."
;;

module Seq_memo = struct
  let memoize m f =
    let memo_table = Hashtbl.create m in
    fun x -> Hashtbl.find_or_add memo_table x ~default:(fun () -> f x)
  ;;

  let memo_rec m f_norec x =
    let rec f = lazy (memoize m (fun x -> f_norec (force f) x)) in
    force f x
  ;;

  module String_pair = struct
    type t = string * string [@@deriving sexp_of, hash, compare]
  end

  let dist =
    memo_rec
      (module String_pair)
      (fun dist (s, t) ->
        match String.length s, String.length t with
        | 0, x | x, 0 -> x
        | len_s, len_t ->
          let s' = String.drop_suffix s 1 in
          let t' = String.drop_suffix t 1 in
          let cost_to_drop_both =
            if Char.( = ) s.[len_s - 1] t.[len_t - 1] then 0 else 1
          in
          let d1 = dist (s', t) + 1 in
          let d2 = dist (s, t') + 1 in
          let d3 = dist (s', t') + cost_to_drop_both in
          let ( ++ ) = Int.min in
          d1 ++ d2 ++ d3)
  ;;

  let dist s t = dist (s, t)

  let dist_fixed_text ~at_most =
    dist (String.prefix long_s at_most) (String.prefix long_t at_most)
  ;;
end

module Par_memo = struct
  module Mutex = Stdlib.Mutex

  (* This is the one bit of shared state, so we lock it when we look
     up in the hashtable, but we release when we do the actual
     computation.

     Note that this can lead to some double-sets, i.e., if the same
     value is looked for twice, two computations will be dispatched in
     parallel, and the results will both be used to update the table.
 *)
  let memoize m f =
    let mx = Mutex.create () in
    let memo_table = Hashtbl.create m in
    fun x ->
      Mutex.lock mx;
      match Hashtbl.find memo_table x with
      | Some res ->
        Mutex.unlock mx;
        res
      | None ->
        Mutex.unlock mx;
        let res = f x in
        Mutex.lock mx;
        Hashtbl.set memo_table ~key:x ~data:res;
        Mutex.unlock mx;
        res
  ;;

  let memo_rec m f_norec x =
    let rec f = lazy (memoize m (fun x -> f_norec (force f) x)) in
    force f x
  ;;

  module String_pair = struct
    type t = string * string [@@deriving sexp_of, hash, compare]
  end

  module Task = Domainslib.Task

  let dist pool =
    let async f = Task.async pool f in
    let await x = Task.await pool x in
    memo_rec
      (module String_pair)
      (fun dist (s, t) ->
        match String.length s, String.length t with
        | 0, x | x, 0 -> x
        | len_s, len_t ->
          let s' = String.drop_suffix s 1 in
          let t' = String.drop_suffix t 1 in
          let cost_to_drop_both =
            if Char.( = ) s.[len_s - 1] t.[len_t - 1] then 0 else 1
          in
          let d1 = async (fun () -> dist (s', t) + 1) in
          let d2 = async (fun () -> dist (s, t') + 1) in
          let d3 = async (fun () -> dist (s', t') + cost_to_drop_both) in
          let ( ++ ) = Int.min in
          await d1 ++ await d2 ++ await d3)
  ;;

  let dist pool s t = dist pool (s, t)

  let dist ~num_domains s t =
    let pool = Task.setup_pool ~num_domains () in
    let res = Task.run pool (fun () -> dist pool s t) in
    Task.teardown_pool pool;
    res
  ;;

  let dist_fixed_text ~num_domains ~at_most =
    dist
      ~num_domains
      (String.prefix long_s at_most)
      (String.prefix long_t at_most)
  ;;
end
