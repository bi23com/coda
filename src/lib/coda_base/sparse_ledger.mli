open Core
open Import
open Snark_params.Tick

type t [@@deriving bin_io, sexp]

val merkle_root : t -> Ledger_hash.t

val path_exn :
  t -> int -> [`Left of Ledger_hash.t | `Right of Ledger_hash.t] list

val get_exn :
     t
  -> int
  -> ( Account.key
     , Currency.Balance.t
     , Account.Nonce.t
     , Receipt.Chain_hash.t )
     Account.t_

val set_exn :
     t
  -> int
  -> ( Account.key
     , Currency.Balance.t
     , Account.Nonce.t
     , Receipt.Chain_hash.t )
     Account.t_
  -> t

val find_index_exn : t -> Account.key -> int

val of_root : Ledger_hash.t -> t

val apply_user_command_exn : t -> User_command.t -> t

val apply_transaction_exn : t -> Transaction.t -> t

val of_ledger_subset_exn : Ledger.t -> Public_key.Compressed.t list -> t

val of_ledger_index_subset_exn : Ledger.Any_ledger.witness -> int list -> t

val iteri : t -> f:(Account.Index.t -> Account.t -> unit) -> unit

val handler : t -> Handler.t Staged.t
