# StackFin: DeFi Personal Loans Protocol

A decentralized lending protocol built on Stacks that enables personal loans using STX as collateral.

## Features
- Create loan requests with customizable terms
- Fund loans and earn interest
- Automated loan repayments
- Collateral management
- Liquidation mechanism for defaulted loans

## Setup and Installation
1. Clone the repository
2. Install Clarinet
3. Run `clarinet check` to verify contracts
4. Run `clarinet test` to execute test suite

## Usage Examples
```clarity
;; Create a loan request
(contract-call? .stackfin request-loan u1000000 u120 u50)

;; Fund a loan
(contract-call? .stackfin fund-loan u1 {sender: tx-sender, amount: u1000000})

;; Make loan payment
(contract-call? .stackfin make-payment u1 u100000)

;; Check loan status
(contract-call? .stackfin get-loan-info u1)
```

## Architecture
- Loan requests stored with unique IDs
- Collateral locked in contract during loan period
- Interest calculated based on loan duration
- Automatic liquidation if loan-to-value ratio drops below threshold

## Dependencies
- Clarity language
- Clarinet for testing and deployment
