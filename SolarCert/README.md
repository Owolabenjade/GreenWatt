# Renewable Energy Certificate (REC) Smart Contract

This Clarity smart contract implements a system for managing Renewable Energy Certificates (RECs) on the Stacks blockchain. It allows for minting, transferring, and tracking RECs, including validator management and transfer logging.

## Features

- **Validator Management**: Contract owner can register or remove validators.
- **Token Minting**: Validators can mint new REC tokens with detailed metadata.
- **Token Transfer**: Token owners can transfer RECs to others, with restrictions to prevent unauthorized transfers.
- **Transfer Logging**: Each transfer is logged using a circular buffer for transparency and auditing.
- **Token Expiration**: Tokens have an expiration mechanism to enforce validity periods.
- **Data Retrieval**: Functions to query token details, validator status, token expiration, and transfer logs.

## Contract Details

- **Language**: Clarity
- **Blockchain**: Stacks

## Functions

### Public Functions

#### 1. `register-validator (validator principal)`

Registers a new validator. Only the contract owner can call this function.

- **Parameters**:
  - `validator`: The principal address of the validator to register.
- **Returns**: `ok true` on success.

#### 2. `remove-validator (validator principal)`

Removes an existing validator. Only the contract owner can call this function.

- **Parameters**:
  - `validator`: The principal address of the validator to remove.
- **Returns**: `ok true` on success.

#### 3. `mint-rec (generator principal, mwh-amount uint, location (string-ascii 50), technology (string-ascii 20), device-id (string-ascii 34))`

Mints a new REC token. Only registered validators can call this function.

- **Parameters**:
  - `generator`: The principal address of the energy generator.
  - `mwh-amount`: The amount of energy produced in MWh.
  - `location`: The location where the energy was generated.
  - `technology`: The technology used to generate the energy.
  - `device-id`: The unique identifier of the generation device.
- **Returns**: `ok token-id` on success, where `token-id` is the ID of the newly minted token.

#### 4. `transfer (token-id uint, recipient principal)`

Transfers ownership of a REC token to another principal.

- **Parameters**:
  - `token-id`: The ID of the token to transfer.
  - `recipient`: The principal address of the new owner.
- **Returns**: `ok true` on success.

### Read-Only Functions

#### 1. `get-token (token-id uint)`

Retrieves the details of a specific token.

- **Parameters**:
  - `token-id`: The ID of the token.
- **Returns**: Token data if the token exists.

#### 2. `is-validator (address principal)`

Checks if an address is a registered validator.

- **Parameters**:
  - `address`: The principal address to check.
- **Returns**: `true` if the address is a validator, `false` otherwise.

#### 3. `is-token-expired (token-id uint)`

Checks if a token has expired.

- **Parameters**:
  - `token-id`: The ID of the token.
- **Returns**: `true` if the token is expired, `false` otherwise.

#### 4. `get-log-count (token-id uint)`

Retrieves the current log index for a token.

- **Parameters**:
  - `token-id`: The ID of the token.
- **Returns**: The log index (`uint`), indicating the number of transfers (up to 100 due to the circular buffer).

#### 5. `get-transfer-log (token-id uint, log-index uint)`

Retrieves a specific transfer log entry for a token.

- **Parameters**:
  - `token-id`: The ID of the token.
  - `log-index`: The index of the log entry.
- **Returns**: Transfer log data if it exists.

### Private Functions

These functions are used internally for validation and logging purposes.

#### 1. `log-transfer (token-id uint, from principal, to principal)`

Logs a transfer of a token.

#### 2. `validate-mwh-amount (amount uint)`

Validates the MWh amount.

#### 3. `validate-location (loc (string-ascii 50))`

Validates the location string.

#### 4. `validate-technology (tech (string-ascii 20))`

Validates the technology string.

#### 5. `validate-device-id (id (string-ascii 34))`

Validates the device ID string.

## Data Structures

### Tokens Map (`tokens`)

Stores token data keyed by `token-id`.

- **Fields**:
  - `owner`: The current owner (principal).
  - `generator`: The original generator (principal).
  - `mwh-amount`: The energy amount (uint).
  - `generation-time`: Block height when minted (uint).
  - `expiration-time`: Block height when the token expires (uint).
  - `location`: Location string (string-ascii 50).
  - `technology`: Technology string (string-ascii 20).
  - `device-id`: Device ID string (string-ascii 34).
  - `validated`: Whether the token is validated (bool).

### Validators Map (`validators`)

Maps validator addresses to a boolean indicating their status.

### Transfer Logs (`transfer-logs`)

Stores transfer logs using composite keys `{ token-id: uint, log-index: uint }`.

- **Fields**:
  - `from`: Sender's address.
  - `to`: Recipient's address.
  - `timestamp`: Block height of the transfer.

### Log Counters (`log-counters`)

Maps `token-id` to the current log index for transfer logs.

## Installation

To deploy the contract:

1. Ensure you have the necessary development environment for Clarity smart contracts.
2. Copy the contract code into a `.clar` file.
3. Deploy the contract to the Stacks blockchain using the Stacks CLI or an appropriate IDE like [Clarinet](https://github.com/hirosystems/clarinet).

## Usage

### Registering a Validator

Only the contract owner can register a validator.

```clarity
(contract-call? .contract-name register-validator validator-address)
```

### Minting a Token

Validators can mint tokens on behalf of generators.

```clarity
(contract-call? .contract-name mint-rec generator-address mwh-amount location technology device-id)
```

### Transferring a Token

Token owners can transfer tokens to others.

```clarity
(contract-call? .contract-name transfer token-id recipient-address)
```

### Querying Token Details

```clarity
(try! (contract-call? .contract-name get-token token-id))
```

### Checking Validator Status

```clarity
(try! (contract-call? .contract-name is-validator validator-address))
```

### Checking Token Expiration

```clarity
(try! (contract-call? .contract-name is-token-expired token-id))
```

### Retrieving Transfer Logs

#### Step 1: Get the Log Count

```clarity
(try! (contract-call? .contract-name get-log-count token-id))
```

#### Step 2: Retrieve Individual Logs

Loop through the log indices up to the log count:

```clarity
(try! (contract-call? .contract-name get-transfer-log token-id log-index))
```

_Note: Since Clarity does not support loops in contracts, you need to perform the iteration in your application logic._

## Testing

You can write tests using [Clarinet](https://github.com/hirosystems/clarinet) or any other Clarity testing framework.

1. **Set Up the Testing Environment**

   - Install Clarinet:
     ```bash
     cargo install clarinet
     ```

2. **Write Test Cases**

   - Create test files in the `tests` directory.
   - Write test cases for each function, covering successful executions and error conditions.

3. **Run Tests**

   - Run the tests using:
     ```bash
     clarinet test
     ```

4. **Verify Results**

   - Ensure all tests pass and functionalities work as expected.

**Note:** Replace `.contract-name` with the actual name of your deployed contract when making calls.