import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous test cases remain unchanged]

Clarinet.test({
  name: "Handles liquidation correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Setup: Create and fund loan
    let block = chain.mineBlock([
      Tx.contractCall(
        'stackfin',
        'request-loan',
        [types.uint(1000000), types.uint(120), types.uint(50)],
        wallet1.address
      ),
      Tx.contractCall(
        'stackfin',
        'fund-loan',
        [types.uint(1)],
        wallet2.address
      )
    ]);
    
    // Attempt liquidation
    block = chain.mineBlock([
      Tx.contractCall(
        'stackfin',
        'liquidate',
        [types.uint(1)],
        wallet2.address
      )
    ]);
    
    // Should fail as collateral is still sufficient
    block.receipts[0].result.expectErr();
  }
});
