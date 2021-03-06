open Core
open Async
open Coda_base
open Coda_state
open Coda_transition
open Network_peer
open Network_pool
open Pipe_lib

let refused_answer_query_string = "Refused to answer_query"

type exn += No_initial_peers

(* INSTRUCTIONS FOR ADDING A NEW RPC:
 *   - define a new module under the Rpcs module
 *   - add an entry to the Rpcs.rpc GADT definition for the new module (type ('query, 'response) rpc, below)
 *   - add the new constructor for Rpcs.rpc to Rpcs.all_of_type_erased_rpc
 *   - add a pattern matching case to Rpcs.implementation_of_rpc mapping the
 *     new constructor to the new module for your RPC
 *)
module Rpcs = struct
  (* for versioning of the types here, see

     RFC 0012, and

     https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Versioned_rpc/

     The "master" types are the ones used internally in the code base. Each
     version has coercions between their query and response types and the master
     types.
   *)

  module Get_staged_ledger_aux_and_pending_coinbases_at_hash = struct
    module Master = struct
      let name = "get_staged_ledger_aux_and_pending_coinbases_at_hash"

      module T = struct
        type query = State_hash.t

        type response =
          (Staged_ledger.Scan_state.t * Ledger_hash.t * Pending_coinbase.t)
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = State_hash.Stable.V1.t [@@deriving bin_io, version {rpc}]

        type response =
          ( Staged_ledger.Scan_state.Stable.V1.t
          * Ledger_hash.Stable.V1.t
          * Pending_coinbase.Stable.V1.t )
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  module Answer_sync_ledger_query = struct
    module Master = struct
      let name = "answer_sync_ledger_query"

      module T = struct
        type query = Ledger_hash.t * Sync_ledger.Query.t

        type response = Sync_ledger.Answer.t Core.Or_error.t
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = Ledger_hash.Stable.V1.t * Sync_ledger.Query.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response =
          Sync_ledger.Answer.Stable.V1.t Core.Or_error.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  module Get_transition_chain = struct
    module Master = struct
      let name = "get_transition_chain"

      module T = struct
        type query = State_hash.t list [@@deriving sexp, to_yojson]

        type response = External_transition.t list option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = State_hash.Stable.V1.t list
        [@@deriving bin_io, sexp, version {rpc}]

        type response = External_transition.Stable.V1.t list option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  module Get_transition_chain_proof = struct
    module Master = struct
      let name = "get_transition_chain_proof"

      module T = struct
        type query = State_hash.t [@@deriving sexp, to_yojson]

        type response = (State_hash.t * State_body_hash.t list) option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = State_hash.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response =
          (State_hash.Stable.V1.t * State_body_hash.Stable.V1.t list) option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  module Get_ancestry = struct
    module Master = struct
      let name = "get_ancestry"

      module T = struct
        type query = Consensus.Data.Consensus_state.Value.t
        [@@deriving sexp, to_yojson]

        type response =
          ( External_transition.t
          , State_body_hash.t list * External_transition.t )
          Proof_carrying_data.t
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = Consensus.Data.Consensus_state.Value.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response =
          ( External_transition.Stable.V1.t
          , State_body_hash.Stable.V1.t list * External_transition.Stable.V1.t
          )
          Proof_carrying_data.Stable.V1.t
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  module Ban_notify = struct
    module Master = struct
      let name = "ban_notify"

      module T = struct
        (* banned until this time *)
        type query = Core.Time.t [@@deriving sexp]

        type response = unit
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = Core.Time.Stable.V1.t
        [@@deriving bin_io, sexp, version {rpc}]

        type response = unit [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  module Get_best_tip = struct
    module Master = struct
      let name = "get_best_tip"

      module T = struct
        type query = unit [@@deriving sexp, to_yojson]

        type response =
          ( External_transition.t
          , State_body_hash.t list * External_transition.t )
          Proof_carrying_data.t
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = unit [@@deriving bin_io, sexp, version {rpc}]

        type response =
          ( External_transition.Stable.V1.t
          , State_body_hash.Stable.V1.t list * External_transition.Stable.V1.t
          )
          Proof_carrying_data.Stable.V1.t
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  module Get_telemetry_data = struct
    module Telemetry_data = struct
      let yojson_of_ban_status (inet_addr, peer_status) =
        `Assoc
          [ ("IP_address", `String (Unix.Inet_addr.to_string inet_addr))
          ; ("peer_status", Trust_system.Peer_status.to_yojson peer_status) ]

      let yojson_of_ban_statuses ban_statuses =
        `List (List.map ban_statuses ~f:yojson_of_ban_status)

      [%%versioned
      module Stable = struct
        module V1 = struct
          type t =
            { node_ip_addr: Core.Unix.Inet_addr.Stable.V1.t
            ; node_peer_id: Network_peer.Peer.Id.Stable.V1.t
            ; peers: Network_peer.Peer.Stable.V1.t list
            ; block_producers:
                Signature_lib.Public_key.Compressed.Stable.V1.t list
            ; protocol_state_hash: State_hash.Stable.V1.t
            ; ban_statuses:
                ( Core.Unix.Inet_addr.Stable.V1.t
                * Trust_system.Peer_status.Stable.V1.t )
                list
            ; k_block_hashes: State_hash.Stable.V1.t list }

          (* N.B.: the [@@to_yojson ...] per-field spec didn't seem to work, so we write
             the full function in gory detail
           *)
          let to_yojson t =
            `Assoc
              [ ( "node_ip_addr"
                , `String (Unix.Inet_addr.to_string t.node_ip_addr) )
              ; ("node_peer_id", `String t.node_peer_id)
              ; ( "peers"
                , `List
                    (List.map t.peers ~f:Network_peer.Peer.Stable.V1.to_yojson)
                )
              ; ( "block_producers"
                , `List
                    (List.map t.block_producers
                       ~f:
                         Signature_lib.Public_key.Compressed.Stable.V1
                         .to_yojson) )
              ; ( "protocol_state_hash"
                , State_hash.Stable.V1.to_yojson t.protocol_state_hash )
              ; ("ban_statuses", yojson_of_ban_statuses t.ban_statuses)
              ; ( "k_block_hashes"
                , `List
                    (List.map t.k_block_hashes
                       ~f:State_hash.Stable.V1.to_yojson) ) ]

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t =
        { node_ip_addr: Unix.Inet_addr.t
        ; node_peer_id: Network_peer.Peer.Id.t
        ; peers: Network_peer.Peer.t list
        ; block_producers: Signature_lib.Public_key.Compressed.t list
        ; protocol_state_hash: State_hash.t
        ; ban_statuses: (Unix.Inet_addr.t * Trust_system.Peer_status.t) list
        ; k_block_hashes: State_hash.t list }
    end

    module Master = struct
      let name = "get_telemetry_data"

      module T = struct
        type query = unit [@@deriving sexp, to_yojson]

        type response = Telemetry_data.t Or_error.t
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    let response_to_yojson response =
      match response with
      | Ok telem ->
          Telemetry_data.Stable.V1.to_yojson telem
      | Error err ->
          `Assoc [("error", `String (Error.to_string_hum err))]

    include Perf_histograms.Rpc.Plain.Extend (struct
      include M
      include Master
    end)

    module V1 = struct
      module T = struct
        type query = unit [@@deriving bin_io, sexp, version {rpc}]

        type response =
          Telemetry_data.Stable.V1.t Core_kernel.Or_error.Stable.V1.t
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      module T' =
        Perf_histograms.Rpc.Plain.Decorate_bin_io (struct
            include M
            include Master
          end)
          (T)

      include T'
      include Register (T')
    end
  end

  type ('query, 'response) rpc =
    | Get_staged_ledger_aux_and_pending_coinbases_at_hash
        : ( Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
          , Get_staged_ledger_aux_and_pending_coinbases_at_hash.response )
          rpc
    | Answer_sync_ledger_query
        : ( Answer_sync_ledger_query.query
          , Answer_sync_ledger_query.response )
          rpc
    | Get_transition_chain
        : (Get_transition_chain.query, Get_transition_chain.response) rpc
    | Get_transition_chain_proof
        : ( Get_transition_chain_proof.query
          , Get_transition_chain_proof.response )
          rpc
    | Get_ancestry : (Get_ancestry.query, Get_ancestry.response) rpc
    | Ban_notify : (Ban_notify.query, Ban_notify.response) rpc
    | Get_best_tip : (Get_best_tip.query, Get_best_tip.response) rpc
    | Get_telemetry_data
        : (Get_telemetry_data.query, Get_telemetry_data.response) rpc
    | Consensus_rpc : ('q, 'r) Consensus.Hooks.Rpcs.rpc -> ('q, 'r) rpc

  type rpc_handler =
    | Rpc_handler : ('q, 'r) rpc * ('q, 'r) Rpc_intf.rpc_fn -> rpc_handler

  let implementation_of_rpc : type q r.
      (q, r) rpc -> (q, r) Rpc_intf.rpc_implementation = function
    | Get_staged_ledger_aux_and_pending_coinbases_at_hash ->
        (module Get_staged_ledger_aux_and_pending_coinbases_at_hash)
    | Answer_sync_ledger_query ->
        (module Answer_sync_ledger_query)
    | Get_transition_chain ->
        (module Get_transition_chain)
    | Get_transition_chain_proof ->
        (module Get_transition_chain_proof)
    | Get_ancestry ->
        (module Get_ancestry)
    | Ban_notify ->
        (module Ban_notify)
    | Get_best_tip ->
        (module Get_best_tip)
    | Get_telemetry_data ->
        (module Get_telemetry_data)
    | Consensus_rpc rpc ->
        Consensus.Hooks.Rpcs.implementation_of_rpc rpc

  let match_handler : type q r.
         rpc_handler
      -> (q, r) rpc
      -> do_:((q, r) Rpc_intf.rpc_fn -> 'a)
      -> 'a option =
   fun handler rpc ~do_ ->
    match (rpc, handler) with
    | ( Get_staged_ledger_aux_and_pending_coinbases_at_hash
      , Rpc_handler (Get_staged_ledger_aux_and_pending_coinbases_at_hash, f) )
      ->
        Some (do_ f)
    | Answer_sync_ledger_query, Rpc_handler (Answer_sync_ledger_query, f) ->
        Some (do_ f)
    | Get_transition_chain, Rpc_handler (Get_transition_chain, f) ->
        Some (do_ f)
    | Get_transition_chain_proof, Rpc_handler (Get_transition_chain_proof, f)
      ->
        Some (do_ f)
    | Get_ancestry, Rpc_handler (Get_ancestry, f) ->
        Some (do_ f)
    | Ban_notify, Rpc_handler (Ban_notify, f) ->
        Some (do_ f)
    | Get_best_tip, Rpc_handler (Get_best_tip, f) ->
        Some (do_ f)
    | Consensus_rpc rpc_a, Rpc_handler (Consensus_rpc rpc_b, f) ->
        Consensus.Hooks.Rpcs.match_handler (Rpc_handler (rpc_b, f)) rpc_a ~do_
    | _ ->
        None
end

module Gossip_net = Gossip_net.Make (Rpcs)

module Config = struct
  type log_gossip_heard =
    {snark_pool_diff: bool; transaction_pool_diff: bool; new_state: bool}
  [@@deriving make]

  type t =
    { logger: Logger.t
    ; trust_system: Trust_system.t
    ; time_controller: Block_time.Controller.t
    ; consensus_local_state: Consensus.Data.Local_state.t
    ; genesis_ledger_hash: Ledger_hash.t
    ; creatable_gossip_net: Gossip_net.Any.creatable
    ; is_seed: bool
    ; log_gossip_heard: log_gossip_heard }
  [@@deriving make]
end

type t =
  { logger: Logger.t
  ; trust_system: Trust_system.t
  ; gossip_net: Gossip_net.Any.t
  ; states:
      ( External_transition.t Envelope.Incoming.t
      * Block_time.t
      * (bool -> unit) )
      Strict_pipe.Reader.t
  ; transaction_pool_diffs:
      ( Transaction_pool.Resource_pool.Diff.t Envelope.Incoming.t
      * (bool -> unit) )
      Strict_pipe.Reader.t
  ; snark_pool_diffs:
      (Snark_pool.Resource_pool.Diff.t Envelope.Incoming.t * (bool -> unit))
      Strict_pipe.Reader.t
  ; online_status: [`Offline | `Online] Broadcast_pipe.Reader.t
  ; first_received_message_signal: unit Ivar.t }
[@@deriving fields]

let offline_time =
  Block_time.Span.of_ms @@ Int64.of_int Coda_compile_config.inactivity_ms

let setup_timer time_controller sync_state_broadcaster =
  Block_time.Timeout.create time_controller offline_time ~f:(fun _ ->
      Broadcast_pipe.Writer.write sync_state_broadcaster `Offline
      |> don't_wait_for )

let online_broadcaster time_controller received_messages =
  let online_reader, online_writer = Broadcast_pipe.create `Offline in
  let init =
    Block_time.Timeout.create time_controller
      (Block_time.Span.of_ms Int64.zero)
      ~f:ignore
  in
  Strict_pipe.Reader.fold received_messages ~init ~f:(fun old_timeout _ ->
      let%map () = Broadcast_pipe.Writer.write online_writer `Online in
      Block_time.Timeout.cancel time_controller old_timeout () ;
      setup_timer time_controller online_writer )
  |> Deferred.ignore |> don't_wait_for ;
  online_reader

let wrap_rpc_data_in_envelope conn data =
  Envelope.Incoming.wrap_peer ~data ~sender:conn

let create (config : Config.t)
    ~(get_staged_ledger_aux_and_pending_coinbases_at_hash :
          Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.query
          Envelope.Incoming.t
       -> Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash.response
          Deferred.t)
    ~(answer_sync_ledger_query :
          Rpcs.Answer_sync_ledger_query.query Envelope.Incoming.t
       -> Rpcs.Answer_sync_ledger_query.response Deferred.t)
    ~(get_ancestry :
          Rpcs.Get_ancestry.query Envelope.Incoming.t
       -> Rpcs.Get_ancestry.response Deferred.t)
    ~(get_best_tip :
          Rpcs.Get_best_tip.query Envelope.Incoming.t
       -> Rpcs.Get_best_tip.response Deferred.t)
    ~(get_telemetry_data :
          Rpcs.Get_telemetry_data.query Envelope.Incoming.t
       -> Rpcs.Get_telemetry_data.response Deferred.t)
    ~(get_transition_chain_proof :
          Rpcs.Get_transition_chain_proof.query Envelope.Incoming.t
       -> Rpcs.Get_transition_chain_proof.response Deferred.t)
    ~(get_transition_chain :
          Rpcs.Get_transition_chain.query Envelope.Incoming.t
       -> Rpcs.Get_transition_chain.response Deferred.t) =
  let run_for_rpc_result conn data ~f action_msg msg_args =
    let data_in_envelope = wrap_rpc_data_in_envelope conn data in
    let sender = Envelope.Incoming.sender data_in_envelope in
    let%bind () =
      Trust_system.(
        record_envelope_sender config.trust_system config.logger sender
          Actions.(Made_request, Some (action_msg, msg_args)))
    in
    let%bind result = f data_in_envelope in
    return (result, sender)
  in
  let record_unknown_item result sender action_msg msg_args =
    let%map () =
      if Option.is_none result then
        Trust_system.(
          record_envelope_sender config.trust_system config.logger sender
            Actions.(Requested_unknown_item, Some (action_msg, msg_args)))
      else return ()
    in
    result
  in
  let validate_protocol_versions ~rpc_name sender external_transition =
    let open Trust_system.Actions in
    let External_transition.{valid_current; valid_next; matches_daemon} =
      External_transition.protocol_version_status external_transition
    in
    let%bind () =
      if valid_current then return ()
      else
        let actions =
          ( Sent_invalid_protocol_version
          , Some
              ( "$rpc_name: external transition with invalid current protocol \
                 version"
              , [ ("rpc_name", `String rpc_name)
                ; ( "current_protocol_version"
                  , `String
                      (Protocol_version.to_string
                         (External_transition.current_protocol_version
                            external_transition)) ) ] ) )
        in
        Trust_system.record_envelope_sender config.trust_system config.logger
          sender actions
    in
    let%bind () =
      if valid_next then return ()
      else
        let actions =
          ( Sent_invalid_protocol_version
          , Some
              ( "$rpc_name: external transition with invalid proposed \
                 protocol version"
              , [ ("rpc_name", `String rpc_name)
                ; ( "proposed_protocol_version"
                  , `String
                      (Protocol_version.to_string
                         (Option.value_exn
                            (External_transition.proposed_protocol_version_opt
                               external_transition))) ) ] ) )
        in
        Trust_system.record_envelope_sender config.trust_system config.logger
          sender actions
    in
    let%map () =
      if matches_daemon then return ()
      else
        let actions =
          ( Sent_mismatched_protocol_version
          , Some
              ( "$rpc_name: current protocol version in external transition \
                 does not match daemon current protocol version"
              , [ ("rpc_name", `String rpc_name)
                ; ( "current_protocol_version"
                  , `String
                      (Protocol_version.to_string
                         (External_transition.current_protocol_version
                            external_transition)) )
                ; ( "daemon_current_protocol_version"
                  , `String Protocol_version.(to_string @@ get_current ()) ) ]
              ) )
        in
        Trust_system.record_envelope_sender config.trust_system config.logger
          sender actions
    in
    valid_current && valid_next && matches_daemon
  in
  (* each of the passed-in procedures expects an enveloped input, so
     we wrap the data received via RPC *)
  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc conn ~version:_
      hash =
    let action_msg = "Staged ledger and pending coinbases at hash: $hash" in
    let msg_args = [("hash", State_hash.to_yojson hash)] in
    let%bind result, sender =
      run_for_rpc_result conn hash
        ~f:get_staged_ledger_aux_and_pending_coinbases_at_hash action_msg
        msg_args
    in
    record_unknown_item result sender action_msg msg_args
  in
  let answer_sync_ledger_query_rpc conn ~version:_ ((hash, query) as sync_query)
      =
    let%bind result, sender =
      run_for_rpc_result conn sync_query ~f:answer_sync_ledger_query
        "Answer_sync_ledger_query: $query"
        [("query", Sync_ledger.Query.to_yojson query)]
    in
    let%bind () =
      match result with
      | Ok _ ->
          return ()
      | Error err ->
          (* N.B.: to_string_mach double-quotes the string, don't want that *)
          let err_msg = Error.to_string_hum err in
          if String.is_prefix err_msg ~prefix:refused_answer_query_string then
            Trust_system.(
              record_envelope_sender config.trust_system config.logger sender
                Actions.
                  ( Requested_unknown_item
                  , Some
                      ( "Sync ledger query with hash: $hash, query: $query, \
                         with error: $error"
                      , [ ("hash", Ledger_hash.to_yojson hash)
                        ; ( "query"
                          , Syncable_ledger.Query.to_yojson
                              Ledger.Addr.to_yojson query )
                        ; ("error", `String err_msg) ] ) ))
          else return ()
    in
    return result
  in
  let get_ancestry_rpc conn ~version:_ query =
    Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
      "Sending root proof to peer with IP %s"
      (Unix.Inet_addr.to_string conn.Peer.host) ;
    let action_msg = "Get_ancestry query: $query" in
    let msg_args = [("query", Rpcs.Get_ancestry.query_to_yojson query)] in
    let%bind result, sender =
      run_for_rpc_result conn query ~f:get_ancestry action_msg msg_args
    in
    match result with
    | None ->
        record_unknown_item result sender action_msg msg_args
    | Some {proof= _, ext_trans; _} ->
        let%map valid_protocol_versions =
          validate_protocol_versions ~rpc_name:"Get_ancestry" sender ext_trans
        in
        if valid_protocol_versions then result else None
  in
  let get_best_tip_rpc conn ~version:_ query =
    Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
      "Sending best_tip to peer with IP %s"
      (Unix.Inet_addr.to_string conn.Peer.host) ;
    let action_msg = "Get_best_tip. query: $query" in
    let msg_args = [("query", Rpcs.Get_best_tip.query_to_yojson query)] in
    let%bind result, sender =
      run_for_rpc_result conn query ~f:get_best_tip action_msg msg_args
    in
    match result with
    | None ->
        record_unknown_item result sender action_msg msg_args
    | Some {data= data_ext_trans; proof= _, proof_ext_trans} ->
        let%bind valid_data_protocol_versions =
          validate_protocol_versions ~rpc_name:"Get_best_tip (data)" sender
            data_ext_trans
        in
        let%map valid_proof_protocol_versions =
          validate_protocol_versions ~rpc_name:"Get_best_tip (proof)" sender
            proof_ext_trans
        in
        if valid_data_protocol_versions && valid_proof_protocol_versions then
          result
        else None
  in
  let get_telemetry_data_rpc conn ~version:_ query =
    Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
      "Sending telemetry data to peer with IP %s"
      (Unix.Inet_addr.to_string conn.Peer.host) ;
    let action_msg = "Telemetry_data" in
    let msg_args = [] in
    (* if peer doesn't return telemetry data, don't change trust score *)
    let%map result, _sender =
      run_for_rpc_result conn query ~f:get_telemetry_data action_msg msg_args
    in
    result
  in
  let get_transition_chain_proof_rpc conn ~version:_ query =
    Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
      "Sending transition_chain_proof to peer with IP %s"
      (Unix.Inet_addr.to_string conn.Peer.host) ;
    let action_msg = "Get_transition_chain_proof query: $query" in
    let msg_args =
      [("query", Rpcs.Get_transition_chain_proof.query_to_yojson query)]
    in
    let%bind result, sender =
      run_for_rpc_result conn query ~f:get_transition_chain_proof action_msg
        msg_args
    in
    record_unknown_item result sender action_msg msg_args
  in
  let get_transition_chain_rpc conn ~version:_ query =
    Logger.info config.logger ~module_:__MODULE__ ~location:__LOC__
      "Sending transition_chain to peer with IP %s"
      (Unix.Inet_addr.to_string conn.Peer.host) ;
    let action_msg = "Get_transition_chain query: $query" in
    let msg_args =
      [("query", Rpcs.Get_transition_chain.query_to_yojson query)]
    in
    let%bind result, sender =
      run_for_rpc_result conn query ~f:get_transition_chain action_msg msg_args
    in
    match result with
    | None ->
        record_unknown_item result sender action_msg msg_args
    | Some ext_trans ->
        let%map valid_protocol_versions =
          Deferred.List.map ext_trans
            ~f:
              (validate_protocol_versions ~rpc_name:"Get_transition_chain"
                 sender)
        in
        if List.for_all valid_protocol_versions ~f:(Bool.equal true) then
          result
        else None
  in
  let ban_notify_rpc conn ~version:_ ban_until =
    (* the port in `conn' is an ephemeral port, not of interest *)
    Logger.warn config.logger ~module_:__MODULE__ ~location:__LOC__
      "Node banned by peer $peer until $ban_until"
      ~metadata:
        [ ("peer", `String (Unix.Inet_addr.to_string conn.Peer.host))
        ; ( "ban_until"
          , `String (Time.to_string_abs ~zone:Time.Zone.utc ban_until) ) ] ;
    (* no computation to do; we're just getting notification *)
    Deferred.unit
  in
  let rpc_handlers =
    let open Rpcs in
    [ Rpc_handler
        ( Get_staged_ledger_aux_and_pending_coinbases_at_hash
        , get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc )
    ; Rpc_handler (Answer_sync_ledger_query, answer_sync_ledger_query_rpc)
    ; Rpc_handler (Get_best_tip, get_best_tip_rpc)
    ; Rpc_handler (Get_telemetry_data, get_telemetry_data_rpc)
    ; Rpc_handler (Get_ancestry, get_ancestry_rpc)
    ; Rpc_handler (Get_transition_chain, get_transition_chain_rpc)
    ; Rpc_handler (Get_transition_chain_proof, get_transition_chain_proof_rpc)
    ; Rpc_handler (Ban_notify, ban_notify_rpc) ]
    @ Consensus.Hooks.Rpcs.(
        List.map
          (rpc_handlers ~logger:config.logger
             ~local_state:config.consensus_local_state
             ~genesis_ledger_hash:
               (Frozen_ledger_hash.of_ledger_hash config.genesis_ledger_hash))
          ~f:(fun (Rpc_handler (rpc, f)) ->
            Rpcs.(Rpc_handler (Consensus_rpc rpc, f)) ))
  in
  let%map gossip_net =
    Gossip_net.Any.create config.creatable_gossip_net rpc_handlers
  in
  don't_wait_for
    (Gossip_net.Any.on_first_connect gossip_net ~f:(fun () ->
         (* After first_connect this list will only be empty if we filtered out all the peers due to mismatched chain id. *)
         don't_wait_for
           (let%map initial_peers = Gossip_net.Any.peers gossip_net in
            if List.is_empty initial_peers && not config.is_seed then (
              Logger.fatal config.logger
                "Failed to connect to any initial peers" ~module_:__MODULE__
                ~location:__LOC__ ;
              raise No_initial_peers )) )) ;
  (* TODO: Think about buffering:
     I.e., what do we do when too many messages are coming in, or going out.
     For example, some things you really want to not drop (like your outgoing
     block announcment).
  *)
  let received_gossips, online_notifier =
    Strict_pipe.Reader.Fork.two
      (Gossip_net.Any.received_message_reader gossip_net)
  in
  let online_status =
    online_broadcaster config.time_controller online_notifier
  in
  let first_received_message_signal = Ivar.create () in
  let states, snark_pool_diffs, transaction_pool_diffs =
    Strict_pipe.Reader.partition_map3 received_gossips
      ~f:(fun (envelope, valid_cb) ->
        Ivar.fill_if_empty first_received_message_signal () ;
        Coda_metrics.(Counter.inc_one Network.gossip_messages_received) ;
        match Envelope.Incoming.data envelope with
        | New_state state ->
            Perf_histograms.add_span ~name:"external_transition_latency"
              (Core.Time.abs_diff
                 Block_time.(now config.time_controller |> to_time)
                 ( External_transition.protocol_state state
                 |> Protocol_state.blockchain_state
                 |> Blockchain_state.timestamp |> Block_time.to_time )) ;
            if config.log_gossip_heard.new_state then
              Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
                "Received a block $block from $sender"
                ~metadata:
                  [ ("external_transition", External_transition.to_yojson state)
                  ; ( "state_hash"
                    , External_transition.state_hash state
                      |> State_hash.to_yojson )
                  ; ( "sender"
                    , Envelope.(Sender.to_yojson (Incoming.sender envelope)) )
                  ] ;
            `Fst
              ( Envelope.Incoming.map envelope ~f:(fun _ -> state)
              , Block_time.now config.time_controller
              , valid_cb )
        | Snark_pool_diff diff ->
            if config.log_gossip_heard.snark_pool_diff then
              Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
                "Received Snark-pool diff $work from $sender"
                ~metadata:
                  [ ("work", Snark_pool.Resource_pool.Diff.compact_json diff)
                  ; ( "sender"
                    , Envelope.(Sender.to_yojson (Incoming.sender envelope)) )
                  ] ;
            Coda_metrics.(
              Counter.inc_one Snark_work.completed_snark_work_received_gossip) ;
            `Snd (Envelope.Incoming.map envelope ~f:(fun _ -> diff), valid_cb)
        | Transaction_pool_diff diff ->
            if config.log_gossip_heard.transaction_pool_diff then
              Logger.debug config.logger ~module_:__MODULE__ ~location:__LOC__
                "Received transaction-pool diff $txns from $sender"
                ~metadata:
                  [ ("txns", Transaction_pool.Resource_pool.Diff.to_yojson diff)
                  ; ( "sender"
                    , Envelope.(Sender.to_yojson (Incoming.sender envelope)) )
                  ] ;
            let diff' =
              List.filter diff ~f:(fun cmd ->
                  if User_command.is_trivial cmd then (
                    Logger.debug config.logger ~module_:__MODULE__
                      ~location:__LOC__
                      "Filtering trivial user command in transaction-pool \
                       diff $cmd from $sender"
                      ~metadata:
                        [ ("cmd", User_command.to_yojson cmd)
                        ; ( "sender"
                          , Envelope.(
                              Sender.to_yojson (Incoming.sender envelope)) ) ] ;
                    false )
                  else true )
            in
            `Trd (Envelope.Incoming.map envelope ~f:(fun _ -> diff'), valid_cb)
    )
  in
  { gossip_net
  ; logger= config.logger
  ; trust_system= config.trust_system
  ; states
  ; snark_pool_diffs
  ; transaction_pool_diffs
  ; online_status
  ; first_received_message_signal }

(* lift and expose select gossip net functions *)
include struct
  open Gossip_net.Any

  let lift f {gossip_net; _} = f gossip_net

  let peers = lift peers

  let initial_peers = lift initial_peers

  let ban_notification_reader = lift ban_notification_reader

  let random_peers = lift random_peers

  let random_peers_except = lift random_peers_except

  (* these cannot be directly lifted due to the value restriction *)
  let query_peer t = lift query_peer t

  let on_first_connect t = lift on_first_connect t

  let on_first_high_connectivity t = lift on_first_high_connectivity t

  let ip_for_peer t peer_id =
    (lift ip_for_peer) t peer_id >>| Option.map ~f:(fun peer -> peer.Peer.host)
end

let on_first_received_message {first_received_message_signal; _} ~f =
  Ivar.read first_received_message_signal >>| f

let fill_first_received_message_signal {first_received_message_signal; _} =
  Ivar.fill_if_empty first_received_message_signal ()

(* TODO: Have better pushback behavior *)
let broadcast t msg =
  Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:[("message", Gossip_net.Message.msg_to_yojson msg)]
    !"Broadcasting %s over gossip net"
    (Gossip_net.Message.summary msg) ;
  Gossip_net.Any.broadcast t.gossip_net msg

let broadcast_state t state = broadcast t (Gossip_net.Message.New_state state)

let broadcast_transaction_pool_diff t diff =
  broadcast t (Gossip_net.Message.Transaction_pool_diff diff)

let broadcast_snark_pool_diff t diff =
  broadcast t (Gossip_net.Message.Snark_pool_diff diff)

(* TODO: This is kinda inefficient *)
let find_map xs ~f =
  let open Async in
  let ds = List.map xs ~f in
  let filter ~f =
    Deferred.bind ~f:(fun x -> if f x then return x else Deferred.never ())
  in
  let none_worked =
    Deferred.bind (Deferred.all ds) ~f:(fun ds ->
        if List.for_all ds ~f:Option.is_none then return None
        else Deferred.never () )
  in
  Deferred.any (none_worked :: List.map ~f:(filter ~f:Option.is_some) ds)

(* TODO: Don't copy and paste *)
let find_map' xs ~f =
  let open Async in
  let ds = List.map xs ~f in
  let filter ~f =
    Deferred.bind ~f:(fun x -> if f x then return x else Deferred.never ())
  in
  let none_worked =
    Deferred.bind (Deferred.all ds) ~f:(fun ds ->
        (* TODO: Validation applicative here *)
        if List.for_all ds ~f:Or_error.is_error then
          return (Or_error.error_string "all none")
        else Deferred.never () )
  in
  Deferred.any (none_worked :: List.map ~f:(filter ~f:Or_error.is_ok) ds)

let online_status t = t.online_status

let make_rpc_request ~rpc ~label t peer input =
  let open Deferred.Let_syntax in
  match%map query_peer t peer.Peer.peer_id rpc input with
  | Connected {data= Ok (Some response); _} ->
      Ok response
  | Connected {data= Ok None; _} ->
      Or_error.errorf
        !"Peer %{sexp:Network_peer.Peer.Id.t} doesn't have the requested %s"
        peer.peer_id label
  | Connected {data= Error e; _} | Failed_to_connect e ->
      Error e

let get_transition_chain_proof =
  make_rpc_request ~rpc:Rpcs.Get_transition_chain_proof ~label:"transition"

let get_transition_chain =
  make_rpc_request ~rpc:Rpcs.Get_transition_chain ~label:"chain of transitions"

let get_best_tip t peer =
  make_rpc_request ~rpc:Rpcs.Get_best_tip ~label:"best tip" t peer ()

let ban_notify t peer banned_until =
  query_peer t peer.Peer.peer_id Rpcs.Ban_notify banned_until
  >>| Fn.const (Ok ())

let net2 t = Gossip_net.Any.net2 t.gossip_net

let try_non_preferred_peers (type b) t input peers ~rpc :
    b Envelope.Incoming.t Deferred.Or_error.t =
  let max_current_peers = 8 in
  let rec loop peers num_peers =
    if num_peers > max_current_peers then
      return
        (Or_error.error_string
           "None of randomly-chosen peers can handle the request")
    else
      let current_peers, remaining_peers = List.split_n peers num_peers in
      find_map' current_peers ~f:(fun peer ->
          let%bind response_or_error =
            query_peer t peer.Peer.peer_id rpc input
          in
          match response_or_error with
          | Connected ({data= Ok (Some data); _} as envelope) ->
              let%bind () =
                Trust_system.(
                  record t.trust_system t.logger peer.host
                    Actions.
                      ( Fulfilled_request
                      , Some ("Nonpreferred peer returned valid response", [])
                      ))
              in
              return (Ok (Envelope.Incoming.map envelope ~f:(Fn.const data)))
          | Connected {data= Ok None; _} ->
              loop remaining_peers (2 * num_peers)
          | _ ->
              loop remaining_peers (2 * num_peers) )
  in
  loop peers 1

let rpc_peer_then_random (type b) t peer_id input ~rpc :
    b Envelope.Incoming.t Deferred.Or_error.t =
  let retry () =
    let%bind peers = random_peers t 8 in
    try_non_preferred_peers t input peers ~rpc
  in
  match%bind query_peer t peer_id rpc input with
  | Connected {data= Ok (Some response); sender} ->
      let%bind () =
        match sender with
        | Local ->
            return ()
        | Remote (sender, _) ->
            Trust_system.(
              record t.trust_system t.logger sender
                Actions.
                  ( Fulfilled_request
                  , Some ("Preferred peer returned valid response", []) ))
      in
      return (Ok (Envelope.Incoming.wrap ~data:response ~sender))
  | Connected {data= Ok None; sender} ->
      let%bind () =
        match sender with
        | Remote (sender, _) ->
            Trust_system.(
              record t.trust_system t.logger sender
                Actions.
                  ( Violated_protocol
                  , Some ("When querying preferred peer, got no response", [])
                  ))
        | Local ->
            return ()
      in
      retry ()
  | Connected {data= Error e; sender} ->
      (* FIXME #4094: determine if more specific actions apply here *)
      let%bind () =
        match sender with
        | Remote (sender, _) ->
            Trust_system.(
              record t.trust_system t.logger sender
                Actions.
                  ( Outgoing_connection_error
                  , Some
                      ( "Error while doing RPC"
                      , [("error", `String (Error.to_string_hum e))] ) ))
        | Local ->
            return ()
      in
      retry ()
  | Failed_to_connect _ ->
      (* Since we couldn't connect, we have no IP to ban. *)
      retry ()

let get_staged_ledger_aux_and_pending_coinbases_at_hash t inet_addr input =
  rpc_peer_then_random t inet_addr input
    ~rpc:Rpcs.Get_staged_ledger_aux_and_pending_coinbases_at_hash
  >>|? Envelope.Incoming.data

let get_ancestry t inet_addr input =
  rpc_peer_then_random t inet_addr input ~rpc:Rpcs.Get_ancestry

let glue_sync_ledger :
       t
    -> (Coda_base.Ledger_hash.t * Coda_base.Sync_ledger.Query.t)
       Pipe_lib.Linear_pipe.Reader.t
    -> ( Coda_base.Ledger_hash.t
       * Coda_base.Sync_ledger.Query.t
       * Coda_base.Sync_ledger.Answer.t Network_peer.Envelope.Incoming.t )
       Pipe_lib.Linear_pipe.Writer.t
    -> unit =
 fun t query_reader response_writer ->
  (* We attempt to query 3 random peers, retry_max times. We keep track of the
     peers that couldn't answer a particular query and won't try them
     again. *)
  let retry_max = 6 in
  let retry_interval = Core.Time.Span.of_ms 200. in
  let rec answer_query ctr peers_tried query =
    O1trace.trace_event "ask sync ledger query" ;
    let%bind peers = random_peers_except t 3 ~except:peers_tried in
    Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
      !"SL: Querying the following peers %{sexp: Peer.t list}"
      peers ;
    match%bind
      find_map peers ~f:(fun peer ->
          Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
            !"Asking %{sexp: Peer.t} query regarding ledger_hash %{sexp: \
              Ledger_hash.t}"
            peer (fst query) ;
          match%map
            query_peer t peer.peer_id Rpcs.Answer_sync_ledger_query query
          with
          | Connected {data= Ok (Ok answer); sender} ->
              Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
                !"Received answer from peer %{sexp: Peer.t} on ledger_hash \
                  %{sexp: Ledger_hash.t}"
                peer (fst query) ;
              (* TODO : here is a place where an envelope could contain
                 a Peer.t, and not just an IP address, if desired
              *)
              Some (Envelope.Incoming.wrap ~data:answer ~sender)
          | Connected {data= Ok (Error e); _} ->
              Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                "Peer $peer didn't have enough information to answer \
                 ledger_hash query. See error for more details: $error"
                ~metadata:
                  [ ("error", `String (Error.to_string_hum e))
                  ; ("peer", Peer.to_yojson peer) ] ;
              Hash_set.add peers_tried peer ;
              None
          | Connected {data= Error e; _} ->
              Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                "RPC error during ledger_hash query See error for more \
                 details: $error"
                ~metadata:[("error", `String (Error.to_string_hum e))] ;
              Hash_set.add peers_tried peer ;
              None
          | Failed_to_connect err ->
              Logger.warn t.logger ~module_:__MODULE__ ~location:__LOC__
                "Network error: %s" (Error.to_string_mach err) ;
              None )
    with
    | Some answer ->
        Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
          !"Succeeding with answer on ledger_hash %{sexp: Ledger_hash.t}"
          (fst query) ;
        (* TODO *)
        Linear_pipe.write_if_open response_writer (fst query, snd query, answer)
    | None ->
        Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
          !"None of the peers contacted were able to answer ledger_hash query \
            -- trying more" ;
        if ctr > retry_max then Deferred.unit
        else
          let%bind () = Clock.after retry_interval in
          answer_query (ctr + 1) peers_tried query
  in
  Linear_pipe.iter_unordered ~max_concurrency:8 query_reader
    ~f:(answer_query 0 (Peer.Hash_set.of_list []))
  |> don't_wait_for
