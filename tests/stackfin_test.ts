import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures loan request creates with proper collateral",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        'stackfin',
        'request-loan',
        [
          types.uint(1000000), // amount
          types.uint(120),     // duration
          types.uint(50)       // interest rate
        ],
        wallet1.address
      )
    ]);
    
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Verify loan details
    const result = chain.callReadOnlyFn(
      'stackfin',
      'get-loan-info',
      [types.uint(1)],
      wallet1.address
    );
    
    const loan = result.result.expectOk().expectTuple();
    assertEquals(loan['amount'], types.uint(1000000));
    assertEquals(loan['status'], types.ascii("REQUESTED"));
    assertEquals(loan['borrower'], wallet1.address);
  }
});

Clarinet.test({
  name: "Allows funding of loan request",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    // Create loan request
    let block = chain.mineBlock([
      Tx.contractCall(
        'stackfin',
        'request-loan',
        [types.uint(1000000), types.uint(120), types.uint(50)],
        wallet1.address
      )
    ]);
    
    // Fund the loan
    block = chain.mineBlock([
      Tx.contractCall(
        'stackfin',
        'fund-loan',
        [types.uint(1)],
        wallet2.address
      )
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify loan status
    const result = chain.callReadOnlyFn(
      'stackfin',
      'get-loan-info',
      [types.uint(1)],
      wallet1.address
    );
    
    const loan = result.result.expectOk().expectTuple();
    assertEquals(loan['status'], types.ascii("ACTIVE"));
    assertEquals(loan['lender'], types.some(wallet2.address));
  }
});

Clarinet.test({
  name: "Processes loan payments correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
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
    
    // Make partial payment
    block = chain.mineBlock([
      Tx.contractCall(
        'stackfin',
        'make-payment',
        [types.uint(1), types.uint(500000)],
        wallet1.address
      )
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify payment recorded
    const result = chain.callReadOnlyFn(
      'stackfin',
      'get-loan-info',
      [types.uint(1)],
      wallet1.address
    );
    
    const loan = result.result.expectOk().expectTuple();
    assertEquals(loan['paid-amount'], types.uint(500000));
    assertEquals(loan['status'], types.ascii("ACTIVE"));
  }
});
