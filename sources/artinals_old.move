// module artinals::ARTINALS {
//     use sui::url::{Self, Url};
//     use sui::event;
//     use std::string::{Self, String};
//     use sui::dynamic_field as df;  // Import the dynamic_field module
//     use sui::package;
//     use sui::display;
//     use sui::table::{Self, Table};


//     //Errors
//     const E_MISMATCH_TOKENS_AND_URIS: u64 = 1;
//     const E_NOT_CREATOR: u64 = 2;
//     const E_TOKEN_NOT_MUTABLE: u64 = 3;
//     const E_METADATA_FROZEN: u64 = 4;
//     const E_NOT_OWNER: u64 = 5;
//     const E_NO_TOKENS_TO_BURN: u64 = 6;


//     // Define the token structure
//   public struct NFT has key, store {
//     id: UID,
//     artinals_id: u64,
//     creator: address,
//     name: String,
//     description: String,
//     uri: Url,
//     logo_uri: Url,
//     asset_id: u64,
//     max_supply: u64,
//     royalty_percentage: u64,
//     is_mutable: bool,
//     metadata_frozen: bool,
//     royalty_frozen: bool,
//     royalty_authority: bool,
//     compliance_authority: address,
//     is_frozen: bool,
//     collection_id: ID,
// }




//     // One-Time-Witness for the module
//     public struct ARTINALS has drop {}

//     public struct DenyListStatusEvent has copy, drop {
//     collection_id: ID,
//     address: address,
//     is_denied: bool,
// }

//     public struct DenyListAuthorityRevokedEvent has copy, drop {
//     collection_id: ID,
// }

//     // Define events for transfers, approvals, etc.
//     public struct TransferEvent has copy, drop {
//         from: address,
//         to: address,
//         id: ID,
//         amount: u64,
//         royalty: u64,
//         asset_id: u64, // Unique asset ID within the collection
//     }

    

//     public struct CollectionCap has key, store {
//     id: UID,
//     max_supply: u64,
//     current_supply: u64,
//     creator: address,
//     name: String,
//     description: String,
//     uri: Url,
//     logo_uri: Url,
//     royalty_percentage: u64,
//     is_mutable: bool,
//     has_deny_list_authority: bool,
//     has_royalty_authority: bool,
//     compliance_authority: address,
// }

// public struct UserBalance has key, store {
//     id: UID,
//     collection_id: ID,
//     balance: u64
// }

// public fun create_deny_list(ctx: &mut TxContext): Table<address, bool> {
//     table::new<address, bool>(ctx)
// }

//     public struct ForcedTransferEvent has copy, drop {
//         from: address,
//         to: address,
//         id: ID,
//         amount: u64,
//         initiated_by: address,
//         asset_id: u64,
//     }

//     public struct TokenIdCounter has key {
//         id: UID,
//         last_id: u64,
//     }

// public struct TokenFreezeReasonEvent has copy, drop {
//     id: ID,
//     frozen_by: address,
//     reason: String, // Reason for freezing the token
// }

// public struct DenyListKey has copy, drop, store {
//     dummy_field: bool
// }

// public struct ComplianceActionEvent has copy, drop {
//     action_type: String,  // Type of action (e.g., "Freeze", "ForcedTransfer")
//     executed_by: address, // Who executed the action
//     affected_address: address, // Address affected by the action
//     reason: String, // Reason for the action
// }

// public struct NFTMintedEvent has copy, drop {
//     id: ID,
//     artinals_id: u64,
//     creator: address,
//     name: String,
//     asset_id: u64,
// }



//     // Define event for burning NFTs
//     public struct BurnEvent has copy, drop {
//         owner: address,
//         id: ID,
//         amount: u64,
//     }

//     public struct MetadataUpdateEvent has copy, drop {
//     id: ID,
//     new_name: String,
//     new_description: String,
// }

// public struct MutabilityChangeEvent has copy, drop {
//     id: ID,
//     is_mutable: bool,
// }

// public struct RoyaltyUpdateEvent has copy, drop {
//     id: ID,
//     new_royalty_percentage: u64,
// }

// public struct MetadataFrozenEvent has copy, drop {
//     id: ID,
// }

// public struct RoyaltyFrozenEvent has copy, drop {
//     id: ID,
// }


// public struct AddedToDenyListEvent has copy, drop {
//     id: ID,
//     denied_address: address,
// }

// public struct RemovedFromDenyListEvent has copy, drop {
//     id: ID,
//     removed_address: address,
// }

// public struct TokenFrozenEvent has copy, drop {
//     id: ID,
//     frozen_by: address,
// }

// public struct TokenUnfrozenEvent has copy, drop {
//     id: ID,
//     unfrozen_by: address,
// }

// public struct ComplianceAuthorityTransferredEvent has copy, drop {
//     token_id: ID,
//     previous_authority: address,
//     new_authority: address,
// }


// public struct LogoURIUpdateEvent has copy, drop {
//     id: ID,
//     artinals_id: u64,
//     new_logo_uri: Url, // Change to Url type
// }


// public struct DebugEvent has copy, drop {
//     message: String,
//     token_id: ID,
//     is_frozen: bool,
//     sender: address,
//     recipient: address,
// }



    

// // Initialize the TokenIdCounter
//     fun init(witness: ARTINALS, ctx: &mut TxContext) {
//         let publisher = package::claim(witness, ctx);
    
//         let keys = vector[
//             string::utf8(b"name"),
//             string::utf8(b"description"),
//             string::utf8(b"image_url"),
//             string::utf8(b"creator"),
//             string::utf8(b"project_url"),
//         ];
//         let values = vector[
//             string::utf8(b"{name}"),
//             string::utf8(b"{description}"),
//             string::utf8(b"{logo_uri}"),
//             string::utf8(b"{creator}"),
//             string::utf8(b"{uri}"),
//         ];
//         let mut display = display::new_with_fields<NFT>(
//             &publisher, keys, values, ctx
//         );
//         display::update_version(&mut display);

//         transfer::public_transfer(publisher, tx_context::sender(ctx));
//         transfer::public_transfer(display, tx_context::sender(ctx));

//         let counter = TokenIdCounter {
//             id: object::new(ctx),
//             last_id: 0,
//         };
//         transfer::share_object(counter);
//     }


//    public entry fun mint_token(
//     name: vector<u8>, 
//     description: vector<u8>, 
//     initial_supply: u64,
//     max_supply: u64,
//     uri: vector<u8>, 
//     logo_uri: vector<u8>, 
//     royalty_percentage: u64, 
//     is_mutable: bool, 
//     has_deny_list_authority: bool, 
//     has_royalty_authority: bool,
//     compliance_authority: address,
//     counter: &mut TokenIdCounter,
//     ctx: &mut TxContext
// ) {
//     assert!(initial_supply > 0, 1);
//     assert!(max_supply == 0 || initial_supply <= max_supply, 2);


//     let mut collection_cap = CollectionCap {
//         id: object::new(ctx),
//         max_supply,
//         current_supply: initial_supply,
//         creator: tx_context::sender(ctx),
//         name: string::utf8(name),
//         description: string::utf8(description),
//         uri: url::new_unsafe_from_bytes(uri),
//         logo_uri: url::new_unsafe_from_bytes(logo_uri),
//         royalty_percentage,
//         is_mutable,
//         has_deny_list_authority,
//         has_royalty_authority,
//         compliance_authority,
//     };

//     // Initialize deny list as dynamic field with mutable collection_cap
//     df::add(&mut collection_cap.id, 
//         DenyListKey { dummy_field: false }, 
//         create_deny_list(ctx)
//     );

//     let collection_id = object::uid_to_inner(&collection_cap.id);

//     let user_balance = UserBalance {
//         id: object::new(ctx),
//         collection_id,
//         balance: initial_supply
//     };

//     let mut i = 0;
//     while (i < initial_supply) {
//         counter.last_id = counter.last_id + 1;
//         let artinals_id = counter.last_id;

//         let token = NFT {
//             id: object::new(ctx),
//             artinals_id,
//             creator: tx_context::sender(ctx),
//             name: string::utf8(name),
//             description: string::utf8(description),
//             uri: url::new_unsafe_from_bytes(uri),
//             logo_uri: url::new_unsafe_from_bytes(logo_uri),
//             asset_id: i + 1,
//             max_supply,
//             royalty_percentage,
//             is_mutable,
//             metadata_frozen: false,
//             royalty_frozen: false,
//             royalty_authority: has_royalty_authority,
//             compliance_authority,
//             is_frozen: false,
//             collection_id,
//         };

//         event::emit(NFTMintedEvent {
//             id: object::uid_to_inner(&token.id),
//             artinals_id: token.artinals_id,
//             creator: token.creator,
//             name: token.name,
//             asset_id: token.asset_id,
//         });

//         event::emit(TransferEvent {
//             from: tx_context::sender(ctx),
//             to: tx_context::sender(ctx),
//             id: object::uid_to_inner(&token.id),
//             amount: 1,
//             royalty: 0,
//             asset_id: token.asset_id,
//         });

//         transfer::transfer(token, tx_context::sender(ctx));
//         i = i + 1;
//     };

//     transfer::transfer(collection_cap, tx_context::sender(ctx));
//     transfer::transfer(user_balance, tx_context::sender(ctx));
// }


//     // New function to mint additional tokens (only for mintable NFTs)
//    public entry fun mint_additional(
//     collection_cap: &mut CollectionCap,
//     amount: u64,
//     counter: &mut TokenIdCounter,
//     user_balance: &mut UserBalance,
//     ctx: &mut TxContext
// ) {
//     assert!(tx_context::sender(ctx) == collection_cap.creator, 1);
//     assert!(collection_cap.max_supply == 0 || collection_cap.current_supply + amount <= collection_cap.max_supply, 2);
//     assert!(user_balance.collection_id == object::uid_to_inner(&collection_cap.id), 0);
    
//     user_balance.balance = user_balance.balance + amount;
//     let collection_id = object::uid_to_inner(&collection_cap.id);

//     let mut i = 0;
//     while (i < amount) {
//         counter.last_id = counter.last_id + 1;
//         let artinals_id = counter.last_id;

//         let token = NFT {
//             id: object::new(ctx),
//             artinals_id,
//             creator: collection_cap.creator,
//             name: collection_cap.name,
//             description: collection_cap.description,
//             uri: collection_cap.uri,
//             logo_uri: collection_cap.logo_uri,
//             asset_id: collection_cap.current_supply + i + 1,
//             max_supply: collection_cap.max_supply,
//             royalty_percentage: collection_cap.royalty_percentage,
//             is_mutable: collection_cap.is_mutable,
//             metadata_frozen: false,
//             royalty_frozen: false,
//             royalty_authority: collection_cap.has_royalty_authority,
//             compliance_authority: collection_cap.compliance_authority,
//             is_frozen: false,
//             collection_id,
//         };

//         event::emit(TransferEvent {
//             from: tx_context::sender(ctx),
//             to: tx_context::sender(ctx),
//             id: object::uid_to_inner(&token.id),
//             amount: 1,
//             royalty: 0,
//             asset_id: token.asset_id,
//         });

//         event::emit(NFTMintedEvent {
//             id: object::uid_to_inner(&token.id),
//             artinals_id: token.artinals_id,
//             creator: token.creator,
//             name: token.name,
//             asset_id: token.asset_id,
//         });

//         transfer::transfer(token, tx_context::sender(ctx));
//         i = i + 1;
//     };

//     collection_cap.current_supply = collection_cap.current_supply + amount;
// }


// //  drop_collection_cap function
// public fun drop_collection_cap(collection_cap: CollectionCap) {
//     let CollectionCap {
//         mut id,  // Only mark id as mutable since that's what we modify
//         max_supply: _,
//         current_supply: _,
//         creator: _,
//         name: _,
//         description: _,
//         uri: _,
//         logo_uri: _,
//         royalty_percentage: _,
//         is_mutable: _,
//         has_deny_list_authority: _,
//         has_royalty_authority: _,
//         compliance_authority: _,
//     } = collection_cap;

//     if (df::exists_(&id, DenyListKey { dummy_field: false })) {
//         let deny_list = df::remove<DenyListKey, Table<address, bool>>(
//             &mut id,
//             DenyListKey { dummy_field: false }
//         );
//         table::drop(deny_list);
//     };
    
//     object::delete(id);
// }


// public fun update_metadata(
//     token: &mut NFT,
//     new_name: String,
//     new_description: String,
//     new_uri: vector<u8>,  // Change this to vector<u8>
//     new_logo_uri: vector<u8>, // Change this to vector<u8>
//     ctx: &mut TxContext
// ) {
//     assert!(token.is_mutable, 1); // Error if token is not mutable
//     assert!(!token.metadata_frozen, 2); // Error if metadata is frozen
//     assert!(tx_context::sender(ctx) == token.creator, 3); // Only creator can update

//     token.name = new_name;
//     token.description = new_description;
//     token.uri = url::new_unsafe_from_bytes(new_uri); // Convert to Url
//     token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri); // Convert to Url

//     // Emit an event for metadata update
//     event::emit(MetadataUpdateEvent {
//         id: object::uid_to_inner(&token.id),
//         new_name: new_name,
//         new_description: new_description,
//     });
// }

// // New function to update Logo URI of a specific token
//     public fun update_token_logo_uri(
//     token: &mut NFT,
//     new_logo_uri: vector<u8>, // Change this to vector<u8>
//     ctx: &mut TxContext
// ) {
//     assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can update
//     assert!(token.is_mutable, 2); // Token must be mutable
//     assert!(!token.metadata_frozen, 3); // Metadata must not be frozen

//     token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri); // Convert to Url

//     event::emit(LogoURIUpdateEvent {
//         id: object::uid_to_inner(&token.id),
//         artinals_id: token.artinals_id,
//         new_logo_uri: token.logo_uri,
//     });
// }


// public fun toggle_mutability(token: &mut NFT, ctx: &mut TxContext) {
//     assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can toggle
//     token.is_mutable = !token.is_mutable;

//     // Optionally, emit an event for mutability change
//     event::emit(MutabilityChangeEvent {
//         id: object::uid_to_inner(&token.id),
//         is_mutable: token.is_mutable,
//     });
// }

// public fun update_royalty(
//     token: &mut NFT,
//     new_royalty_percentage: u64,
//     ctx: &mut TxContext
// ) {
//     assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can update royalty
//     assert!(token.royalty_authority, 2); // Check if creator has royalty authority
//     assert!(!token.royalty_frozen, 3); // Error if royalty is frozen
//     assert!(new_royalty_percentage <= 10000, 4); // Check for valid percentage

//     token.royalty_percentage = new_royalty_percentage;

//     // Optionally, emit an event for royalty update
//     event::emit(RoyaltyUpdateEvent {
//         id: object::uid_to_inner(&token.id),
//         new_royalty_percentage: new_royalty_percentage,
//     });
// }


// public fun revoke_royalty_authority(token: &mut NFT, ctx: &mut TxContext) {
//     assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can revoke
//     assert!(token.royalty_authority, 2); // Can only revoke if authority exists
//     token.royalty_authority = false;

//     event::emit(RoyaltyFrozenEvent { // Assuming you want to use this event, otherwise create a new one
//         id: object::uid_to_inner(&token.id),
//     });
// }


// public fun freeze_metadata(token: &mut NFT, ctx: &mut TxContext) {
//     assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can freeze
//     assert!(!token.metadata_frozen, 2); // Cannot freeze if already frozen
//     token.metadata_frozen = true;
//     token.is_mutable = false; // Once frozen, metadata is immutable

//     event::emit(MetadataFrozenEvent {
//         id: object::uid_to_inner(&token.id),
//     });
// }

// public fun freeze_royalty(token: &mut NFT, ctx: &mut TxContext) {
//     assert!(tx_context::sender(ctx) == token.creator, 1); // Only creator can freeze
//     assert!(!token.royalty_frozen, 2); // Cannot freeze if already frozen
//     token.royalty_frozen = true;

//     event::emit(RoyaltyFrozenEvent {
//         id: object::uid_to_inner(&token.id),
//     });
// }

// // Function to transfer the freeze authority to another address
// public fun transfer_freeze_authority(
//     token: &mut NFT,
//     new_compliance_authority: address,
//     ctx: &mut TxContext
// ) {
//     // Only the current compliance authority or the token creator can transfer this authority
//     assert!(
//         tx_context::sender(ctx) == token.compliance_authority || tx_context::sender(ctx) == token.creator,
//         1 // Unauthorized access
//     );

//     // Update the compliance authority to the new address
//     token.compliance_authority = new_compliance_authority;

//     // Optionally, emit an event to log this authority transfer
//     event::emit(ComplianceAuthorityTransferredEvent {
//         token_id: object::uid_to_inner(&token.id),
//         previous_authority: tx_context::sender(ctx),
//         new_authority: new_compliance_authority,
//     });
// }

// public entry fun freeze_token(
//     token: &mut NFT, 
//     freeze: bool, 
//     reason: string::String,   
//     ctx: &mut TxContext
// ) {
//     let sender = tx_context::sender(ctx);
    
//     log_debug_event(b"Freeze token attempt - Initial State", token, sender, sender);

//     assert!(
//         sender == token.creator || sender == token.compliance_authority, 
//         1 // Unauthorized access
//     );

//     // Set the token's frozen status
//     token.is_frozen = freeze;

//     if (freeze) {
//         event::emit(TokenFreezeReasonEvent {
//             id: object::uid_to_inner(&token.id),
//             frozen_by: sender,
//             reason: reason,
//         });
//         event::emit(TokenFrozenEvent {
//             id: object::uid_to_inner(&token.id),
//             frozen_by: sender,
//         });
//     } else {
//         event::emit(TokenUnfrozenEvent {
//             id: object::uid_to_inner(&token.id),
//             unfrozen_by: sender,
//         });
//     };

//     log_debug_event(
//         if (freeze) b"Token frozen" else b"Token unfrozen",
//         token,
//         sender,
//         sender
//     );
// }


// // Update add_to_deny_list function to check collection authority
// public fun add_to_deny_list(
//     collection_cap: &mut CollectionCap,
//     addr: address,
//     ctx: &mut TxContext
// ) {
//     assert!(tx_context::sender(ctx) == collection_cap.creator, 1);
//     assert!(collection_cap.has_deny_list_authority, 2);
    
//     let deny_list = df::borrow_mut<DenyListKey, Table<address, bool>>(
//         &mut collection_cap.id,
//         DenyListKey { dummy_field: false }
//     );
    
//     table::add(deny_list, addr, true);

//     event::emit(AddedToDenyListEvent {
//         id: object::uid_to_inner(&collection_cap.id),
//         denied_address: addr,
//     });
// }

// public fun has_deny_list_authority(collection_cap: &CollectionCap): bool {
//     collection_cap.has_deny_list_authority
// }

// public fun is_denied(collection_cap: &CollectionCap, addr: address): bool {
//     let deny_list = df::borrow<DenyListKey, Table<address, bool>>(
//         &collection_cap.id,
//         DenyListKey { dummy_field: false }
//     );
    
//     table::contains(deny_list, addr)
// }

// public fun remove_from_deny_list(
//     collection_cap: &mut CollectionCap,
//     addr: address,
//     ctx: &mut TxContext
// ) {
//     assert!(tx_context::sender(ctx) == collection_cap.creator, 1);
//     assert!(collection_cap.has_deny_list_authority, 2);
    
//     let deny_list = df::borrow_mut<DenyListKey, Table<address, bool>>(
//         &mut collection_cap.id,
//         DenyListKey { dummy_field: false }
//     );
    
//     table::remove(deny_list, addr);

//     event::emit(RemovedFromDenyListEvent {
//         id: object::uid_to_inner(&collection_cap.id),
//         removed_address: addr,
//     });
// }

// public fun has_deny_list(collection_cap: &CollectionCap): bool {
//     df::exists_(&collection_cap.id, DenyListKey { dummy_field: false })
// }

// public fun deny_list_size(collection_cap: &CollectionCap): u64 {
//     let deny_list = df::borrow<DenyListKey, Table<address, bool>>(
//         &collection_cap.id,
//         DenyListKey { dummy_field: false }
//     );
//     table::length(deny_list)
// }


// // Add this helper function
// public fun check_deny_list_restrictions(collection_cap: &CollectionCap, from: address, to: address) {
//     assert!(!is_denied(collection_cap, from), 3);
//     assert!(!is_denied(collection_cap, to), 4);
// }

// public fun revoke_deny_list_authority(
//     collection_cap: &mut CollectionCap,
//     ctx: &mut TxContext
// ) {
//     assert!(tx_context::sender(ctx) == collection_cap.creator, 1);
//     assert!(collection_cap.has_deny_list_authority, 2);
//     collection_cap.has_deny_list_authority = false;

//     event::emit(DenyListAuthorityRevokedEvent {
//         collection_id: object::uid_to_inner(&collection_cap.id),
//     });
// }

// // Update deny list status function
// public fun emit_deny_list_status(
//     collection_cap: &CollectionCap,
//     addr: address
// ) {
//     event::emit(DenyListStatusEvent {
//         collection_id: object::uid_to_inner(&collection_cap.id),
//         address: addr,
//         is_denied: is_denied(collection_cap, addr)
//     });
// }

//     // Transfer a token
//     public entry fun transfer_token(
//     token: NFT,
//     recipient: address,
//     collection_cap: &CollectionCap, // Add collection_cap parameter
//     sender_balance: &mut UserBalance,
//     ctx: &mut TxContext
// ) {
//     let sender = tx_context::sender(ctx);

//     // Log initial state
//     log_debug_event(b"Transfer attempt - Initial State", &token, sender, recipient);

//     // Check frozen state first
//     if (token.is_frozen) {
//         assert!(
//             sender == token.creator || sender == token.compliance_authority,
//             100
//         );
//         log_debug_event(b"Frozen token transfer by authorized party", &token, sender, recipient);
//     } else {
//         log_debug_event(b"Token is not frozen", &token, sender, recipient);
//     };

//     // Check deny list using collection_cap
//     assert!(!is_denied(collection_cap, sender), 3);
//     assert!(!is_denied(collection_cap, recipient), 4);

//     log_debug_event(b"Deny list checks passed", &token, sender, recipient);

//     let royalty = calculate_royalty(1, token.royalty_percentage);

//     // Update sender's balance
//     assert!(sender_balance.collection_id == object::uid_to_inner(&token.id), 0);
//     sender_balance.balance = sender_balance.balance - 1;

//     // Create recipient's balance
//     let recipient_balance = UserBalance {
//         id: object::new(ctx),
//         collection_id: sender_balance.collection_id,
//         balance: 1
//     };
//     transfer::transfer(recipient_balance, recipient);

//     // Emit transfer event
//     event::emit(TransferEvent {
//         from: sender,
//         to: recipient,
//         id: object::uid_to_inner(&token.id),
//         amount: 1,
//         royalty: royalty,
//         asset_id: token.asset_id,
//     });

//     // Log final state before transfer
//     log_debug_event(b"Pre-transfer state - Final log", &token, sender, recipient);

//     // Capture the token ID before transfer
//     let token_id = object::uid_to_inner(&token.id);

//     // Perform the transfer
//     transfer::public_transfer(token, recipient);

//     // We can't log anything about the token after this point, as it has been moved
//     event::emit(DebugEvent {
//         message: string::utf8(b"Transfer completed"),
//         token_id: token_id, // Use the captured token ID
//         is_frozen: true, // We can't check this after transfer, so we use a placeholder value
//         sender: sender,
//         recipient: recipient,
//     });
// }

// public fun forced_transfer_token(
//     _from: address,
//     _to: address,
//     token: &mut NFT,
//     reason: String,
//     _authority: &signer,
//     ctx: &mut TxContext
// ) {
//     assert!(tx_context::sender(ctx) == token.compliance_authority, 1);

//     event::emit(ForcedTransferEvent {
//         from: _from,
//         to: _to,
//         id: object::uid_to_inner(&token.id),
//         amount: 1,
//         initiated_by: tx_context::sender(ctx),
//         asset_id: token.asset_id,
//     });

//     let action_type_str = string::utf8(b"ForcedTransfer");
//     event::emit(ComplianceActionEvent {
//         action_type: action_type_str,
//         executed_by: tx_context::sender(ctx),
//         affected_address: _from,
//         reason: reason,
//     });

//     // Implement actual forced transfer logic here
//     // This might involve changing the owner field of the NFT, if you have one
// }





//     fun calculate_royalty(amount: u64, royalty_percentage: u64): u64 {
//     (amount * royalty_percentage * 100) / 10000
//     }   


//     // Helper function to check if token is frozen
// fun is_token_frozen(token: &NFT): bool {
//     token.is_frozen
// }

// public fun get_deny_list_status(
//     collection_cap: &CollectionCap,
//     addr: address
// ): bool {
//     is_denied(collection_cap, addr)
// }


// // Helper function for logging debug events
// fun log_debug_event(message: vector<u8>, token: &NFT, sender: address, recipient: address) {
//     event::emit(DebugEvent {
//         message: string::utf8(message),
//         token_id: object::uid_to_inner(&token.id),
//         is_frozen: is_token_frozen(token),
//         sender: sender,
//         recipient: recipient,
//     });
// }

// // Update batch_transfer_tokens
// public entry fun batch_transfer_tokens(
//     tokens: vector<NFT>, // Input parameter
//     recipients: vector<address>,
//     collection_cap: &CollectionCap,
//     sender_balance: &mut UserBalance,
//     ctx: &mut TxContext
// ) {
//     let n = vector::length(&recipients);
//     assert!(n == vector::length(&tokens), 1);
    
//     let mut tokens_mut = tokens; // Create mutable copy
//     let mut i = 0;
//     while (i < n) {
//         let token = vector::pop_back(&mut tokens_mut);
//         let recipient = *vector::borrow(&recipients, i);
        
//         // Check if the token belongs to the correct collection
//         assert!(sender_balance.collection_id == token.collection_id, 0);
        
//         // Check deny list using collection_cap
//         assert!(!is_denied(collection_cap, tx_context::sender(ctx)), 3);
//         assert!(!is_denied(collection_cap, recipient), 4);
        
//         // Update sender's balance
//         sender_balance.balance = sender_balance.balance - 1;

//         // Create recipient's balance
//         let recipient_balance = UserBalance {
//             id: object::new(ctx),
//             collection_id: sender_balance.collection_id,
//             balance: 1
//         };
//         transfer::transfer(recipient_balance, recipient);

//         // Emit transfer event
//         event::emit(TransferEvent {
//             from: tx_context::sender(ctx),
//             to: recipient,
//             id: object::uid_to_inner(&token.id),
//             amount: 1,
//             royalty: 0,
//             asset_id: token.asset_id,
//         });

//         // Transfer the NFT to the recipient
//         transfer::public_transfer(token, recipient);
        
//         i = i + 1;
//     };

//     // At this point, tokens should be empty, so we can safely destroy it
//     vector::destroy_empty(tokens_mut);
// }


//     // Batch transfer function
//    public entry fun batch_burn_tokens(
//     tokens: vector<NFT>,
//     collection_cap: &mut CollectionCap,
//     user_balance: &mut UserBalance,
//     ctx: &mut TxContext
// ) {
//     let mut tokens_mut = tokens;
//     let n = vector::length(&tokens_mut);
    
//     let mut i = 0;
//     while (i < n) {
//         let token = vector::pop_back(&mut tokens_mut);
        
//         // Check if the token belongs to the correct collection and user balance
//         assert!(user_balance.collection_id == token.collection_id, 0);
//         assert!(object::uid_to_inner(&collection_cap.id) == token.collection_id, 0);
        
//         burn_token(token, collection_cap, user_balance, ctx);
//         i = i + 1;
//     };

//     // Destroy the empty vector
//     vector::destroy_empty(tokens_mut);
// }


//     // Burn a token
//     public entry fun burn_token(
//     token: NFT,
//     collection_cap: &mut CollectionCap,
//     user_balance: &mut UserBalance,
//     ctx: &mut TxContext
// ) {
//     let sender = tx_context::sender(ctx);
    
//     assert!(sender == token.creator, E_NOT_OWNER);
//     assert!(collection_cap.current_supply > 0, E_NO_TOKENS_TO_BURN);
//     assert!(user_balance.collection_id == token.collection_id, 0);
    
//     user_balance.balance = user_balance.balance - 1;
//     collection_cap.current_supply = collection_cap.current_supply - 1;
    
//     event::emit(BurnEvent {
//         owner: sender,
//         id: object::uid_to_inner(&token.id),
//         amount: 1,
//     });
    
//     let NFT { 
//         id, 
//         artinals_id: _, 
//         creator: _, 
//         name: _, 
//         description: _, 
//         uri: _, 
//         logo_uri: _, 
//         asset_id: _, 
//         max_supply: _, 
//         royalty_percentage: _, 
//         is_mutable: _, 
//         metadata_frozen: _, 
//         royalty_frozen: _, 
//         royalty_authority: _, 
//         compliance_authority: _, 
//         is_frozen: _,
//         collection_id: _ 
//     } = token;
    
//     object::delete(id);
// }



//     public fun get_current_supply(cap: &CollectionCap): u64 {
//     cap.current_supply
// }

// // The get_max_supply function can still work with both NFT and CollectionCap
// public fun get_max_supply(item: &NFT): u64 {
//     item.max_supply
// }

//     public fun get_collection_current_supply(cap: &CollectionCap): u64 {
//         cap.current_supply
//     }

//     public fun get_collection_max_supply(cap: &CollectionCap): u64 {
//     cap.max_supply
// }

// public entry fun batch_update_token_logo_uri(
//     mut tokens: vector<NFT>,
//     new_logo_uris: vector<vector<u8>>,
//     ctx: &mut TxContext
// ) {
//     let sender = tx_context::sender(ctx);
//     let n = vector::length(&tokens);
    
//     // Ensure the number of tokens matches the number of new logo URIs
//     assert!(n == vector::length(&new_logo_uris), E_MISMATCH_TOKENS_AND_URIS);

//     let mut i = 0;
//     while (i < n) {
//         let token = vector::borrow_mut(&mut tokens, i);
//         let new_logo_uri = *vector::borrow(&new_logo_uris, i);

//         // Check if the sender is the creator of the token
//         assert!(sender == token.creator, E_NOT_CREATOR);

//         // Check if the token is mutable and not frozen
//         assert!(token.is_mutable, E_TOKEN_NOT_MUTABLE);
//         assert!(!token.metadata_frozen, E_METADATA_FROZEN);

//         // Update the logo URI
//         token.logo_uri = url::new_unsafe_from_bytes(new_logo_uri);

//         // Emit an event for the logo URI update
//         event::emit(LogoURIUpdateEvent {
//             id: object::uid_to_inner(&token.id),
//             artinals_id: token.artinals_id,
//             new_logo_uri: token.logo_uri,
//         });

//         i = i + 1;
//     };

//     // Transfer the updated tokens back to the sender
//     while (!vector::is_empty(&tokens)) {
//         let token = vector::pop_back(&mut tokens);
//         transfer::public_transfer(token, sender);
//     };

//     // Destroy the empty vector
//     vector::destroy_empty(tokens);
// }

   
// public entry fun transfer_existing_nfts_by_quantity(
//     mut tokens: vector<NFT>, // Collection of NFTs held by the sender
//     recipient: address, 
//     quantity: u64, 
//     collection_cap: &CollectionCap,  // Add collection_cap parameter
//     sender_balance: &mut UserBalance,
//     ctx: &mut TxContext
// ) {
//     // Get sender address
//     let sender = tx_context::sender(ctx);
    
//     // Check deny list restrictions for both sender and recipient
//     assert!(!is_denied(collection_cap, sender), 3); // Sender is not denied
//     assert!(!is_denied(collection_cap, recipient), 4); // Recipient is not denied
    
//     // Ensure that the sender has enough NFTs to transfer
//     let sender_nft_count = vector::length(&tokens);
//     assert!(sender_nft_count >= quantity, E_NO_TOKENS_TO_BURN);

//     // Create recipient balance object
//     let recipient_balance = UserBalance {
//         id: object::new(ctx),
//         collection_id: sender_balance.collection_id,
//         balance: quantity
//     };

//     // Update sender's balance
//     sender_balance.balance = sender_balance.balance - quantity;

//     // Transfer balance object to recipient
//     transfer::transfer(recipient_balance, recipient);

//     let mut i = 0;
//     while (i < quantity) {
//         let token = vector::pop_back(&mut tokens);
        
//         // Verify token belongs to the same collection
//         assert!(
//             object::uid_to_inner(&collection_cap.id) == token.collection_id,
//             0  // Invalid collection ID
//         );

//         // Verify token is not frozen before transfer
//         assert!(!token.is_frozen || sender == token.creator || sender == token.compliance_authority, 100);

//         // Calculate royalty for the transfer
//         let royalty = calculate_royalty(1, token.royalty_percentage);

//         // Emit transfer event
//         event::emit(TransferEvent {
//             from: sender,
//             to: recipient,
//             id: object::uid_to_inner(&token.id),
//             amount: 1,
//             royalty,
//             asset_id: token.asset_id,
//         });

//         // Log transfer attempt
//         log_debug_event(
//             b"Batch transfer token attempt",
//             &token,
//             sender,
//             recipient
//         );

//         // Transfer the NFT to the recipient
//         transfer::public_transfer(token, recipient);

//         i = i + 1;
//     };

//     // Clean up the empty vector
//     vector::destroy_empty(tokens);

//     // Emit a batch transfer completion event
//     event::emit(ComplianceActionEvent {
//         action_type: string::utf8(b"BatchTransfer"),
//         executed_by: sender,
//         affected_address: recipient,
//         reason: string::utf8(b"Batch transfer by quantity completed"),
//     });
// }

// public fun get_user_balance(user_balance: &UserBalance): u64 {
//     user_balance.balance
// }


// }