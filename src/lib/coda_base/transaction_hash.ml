open Core

include Blake2.Make ()

module Base58_check = Codable.Make_base58_check (struct
  type t = Stable.V1.t [@@deriving bin_io, compare]

  let version_byte = Base58_check.Version_bytes.transaction_hash

  let description = "Transaction Hash"
end)

[%%define_locally
Base58_check.(of_base58_check, of_base58_check_exn, to_base58_check)]

let hash_user_command = Fn.compose digest_string User_command.to_base58_check