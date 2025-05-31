# Community Crowdfunding Platform

A decentralized crowdfunding platform built on the Stacks blockchain using Clarity smart contracts. This platform enables users to create fundraising campaigns and receive peer-to-peer donations with transparent fee management and comprehensive tracking.

## Features

- **Campaign Management**: Create, manage, and deactivate fundraising campaigns
- **Secure Donations**: Peer-to-peer STX transfers with automatic fee collection
- **Transparent Tracking**: Complete donation history and campaign statistics
- **Administrative Controls**: Platform governance and emergency controls
- **Real-time Metrics**: Live campaign status and platform analytics

## Contract Overview

## Key Components

- **Campaign Creation**: Users can launch campaigns with customizable targets and durations
- **Donation Processing**: Secure STX transfers with automatic platform fee deduction
- **Statistical Tracking**: Comprehensive donor and creator analytics
- **Administrative Functions**: Platform fee management and emergency controls

### Platform Configuration

- **Maximum Fee Rate**: 10% (1000 basis points)
- **Default Fee Rate**: 2.5% (250 basis points)
- **Campaign Duration**: 1 day minimum, 100 days maximum
- **Fee Calculation**: Basis points system (1 basis point = 0.01%)

## Functions

### Campaign Management

## `launch-fundraising-campaign`
Creates a new fundraising campaign.

```clarity
(launch-fundraising-campaign 
  campaign-title 
  campaign-description 
  fundraising-target-amount 
  campaign-duration-blocks)
```

**Parameters:**
- `campaign-title`: Campaign name (max 64 ASCII characters)
- `campaign-description`: Campaign description (max 256 ASCII characters)
- `fundraising-target-amount`: Target amount in microSTX
- `campaign-duration-blocks`: Campaign duration in blocks

**Returns:** Campaign identifier (uint)

### `deactivate-campaign`
Allows campaign creators to deactivate their campaigns.

```clarity
(deactivate-campaign campaign-identifier)
```

### Donation Functions

### `contribute-to-campaign`
Process donations to active campaigns.

```clarity
(contribute-to-campaign campaign-identifier donation-amount)
```

**Parameters:**
- `campaign-identifier`: Target campaign ID
- `donation-amount`: Donation amount in microSTX

**Returns:** Donation breakdown including fees and net amounts

### Read-Only Functions

#### Campaign Information
- `get-campaign-details`: Retrieve complete campaign information
- `get-campaign-status`: Check campaign status and progress
- `get-donation-record`: Get donor's contribution record
- `get-donor-campaign-total`: Get donor's total contribution to campaign

### Statistics
- `get-creator-statistics`: Get creator's overall statistics
- `get-platform-metrics`: Get current platform metrics
- `calculate-donation-breakdown`: Preview fee calculation

### Utility
- `get-current-block-height`: Get current Stacks block height

### Administrative Functions

### `withdraw-platform-fees`
Allows platform administrator to withdraw accumulated fees.

```clarity
(withdraw-platform-fees withdrawal-amount)
```

#### `update-platform-fee-rate`
Update the platform fee rate (admin only).

```clarity
(update-platform-fee-rate new-fee-rate-basis-points)
```

#### `emergency-toggle-campaign`
Emergency campaign activation/deactivation (admin only).

```clarity
(emergency-toggle-campaign campaign-identifier)
```

## Data Structures

### Campaign Record
```clarity
{
  campaign-creator: principal,
  campaign-title: (string-ascii 64),
  campaign-description: (string-ascii 256),
  fundraising-target-amount: uint,
  current-raised-amount: uint,
  campaign-end-block-height: uint,
  campaign-is-currently-active: bool,
  campaign-creation-block-height: uint,
  total-number-of-donors: uint
}
```

### Donation Record
```clarity
{
  total-donated-amount: uint,
  last-donation-block-height: uint,
  number-of-donations: uint
}
```

### Creator Statistics
```clarity
{
  total-campaigns-created: uint,
  total-amount-raised-across-campaigns: uint,
  active-campaigns-count: uint
}
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR-UNAUTHORIZED-ACCESS | Unauthorized access attempt |
| u101 | ERR-CAMPAIGN-DOES-NOT-EXIST | Campaign not found |
| u102 | ERR-CAMPAIGN-HAS-EXPIRED | Campaign is no longer active |
| u103 | ERR-INVALID-DONATION-AMOUNT | Invalid donation amount |
| u104 | ERR-INVALID-CAMPAIGN-DURATION | Invalid campaign duration |
| u105 | ERR-CANNOT-DONATE-TO-OWN-CAMPAIGN | Self-donation not allowed |
| u106 | ERR-CAMPAIGN-ALREADY-INACTIVE | Campaign already inactive |
| u107 | ERR-INSUFFICIENT-CONTRACT-BALANCE | Insufficient contract balance |
| u108 | ERR-STX-TRANSFER-FAILED | STX transfer failed |
| u109 | ERR-INVALID-TARGET-AMOUNT | Invalid target amount |
| u110 | ERR-INVALID-FEE-RATE | Invalid fee rate |

## Usage Examples

### Creating a Campaign
```clarity
;; Create a 30-day campaign with 1000 STX target
(contract-call? .crowdfunding-platform launch-fundraising-campaign
  "Help Build Community Garden"
  "Raising funds to create a sustainable community garden in our neighborhood"
  u1000000000  ;; 1000 STX in microSTX
  u4320        ;; ~30 days in blocks
)
```

### Making a Donation
```clarity
;; Donate 10 STX to campaign #1
(contract-call? .crowdfunding-platform contribute-to-campaign
  u1           ;; Campaign ID
  u10000000    ;; 10 STX in microSTX
)
```

### Checking Campaign Status
```clarity
;; Get campaign status and progress
(contract-call? .crowdfunding-platform get-campaign-status u1)
```

## Security Features

- **Authorization Checks**: Ensures only authorized users can perform restricted actions
- **Input Validation**: Comprehensive validation of all user inputs
- **Transfer Safety**: Uses Clarity's built-in STX transfer functions with error handling
- **Campaign Expiry**: Automatic campaign expiration based on block height
- **Anti-Self-Donation**: Prevents campaign creators from donating to their own campaigns

## Platform Economics

### Fee Structure
- Platform fees are calculated as a percentage of each donation
- Fees are automatically deducted and held in the contract
- Net donation amount is transferred directly to campaign creators
- Platform administrator can withdraw accumulated fees

### Example Fee Calculation (2.5% default rate)
- Donation: 100 STX
- Platform Fee: 2.5 STX
- Amount to Creator: 97.5 STX

## Deployment Notes

1. The contract deployer becomes the platform administrator
2. Initial fee rate is set to 2.5% (250 basis points)
3. All constants are configured for optimal user experience
4. Contract handles all STX transfers automatically

## Development 

### Prerequisites
- Stacks blockchain development environment
- Clarity CLI tools
- STX tokens for testing