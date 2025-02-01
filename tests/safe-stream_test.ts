import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure can purchase coverage with sufficient balance",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "safe-stream",
        "purchase-coverage",
        [types.uint(1000000), types.uint(500000), types.uint(144)],
        wallet_1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "Ensure can submit valid claim",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "safe-stream",
        "purchase-coverage",
        [types.uint(1000000), types.uint(500000), types.uint(144)],
        wallet_1.address
      ),
      Tx.contractCall(
        "safe-stream", 
        "submit-claim",
        [types.uint(400000)],
        wallet_1.address
      )
    ]);

    assertEquals(block.receipts.length, 2);
    assertEquals(block.receipts[1].result, '(ok u0)');
  }
});

Clarinet.test({
  name: "Ensure cannot submit claim without coverage",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        "safe-stream",
        "submit-claim", 
        [types.uint(400000)],
        wallet_1.address
      )
    ]);

    assertEquals(block.receipts[0].result, `(err u103)`);
  }
});
