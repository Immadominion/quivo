/** Transient-error retry for on-chain ops — public devnet RPCs drop sockets and expire blockhashes. */
const TRANSIENT =
  /fetch failed|socket hang up|block height exceeded|Blockhash not found|429|Too Many Requests|timed out|ETIMEDOUT|ECONNRESET|502|503|GOAWAY/i;

export async function retry<T>(label: string, fn: () => Promise<T>, tries = 8): Promise<T> {
  let lastErr: unknown;
  for (let i = 0; i < tries; i++) {
    try {
      return await fn();
    } catch (e: any) {
      lastErr = e;
      if (!TRANSIENT.test(String(e?.message ?? e)) || i === tries - 1) throw e;
      console.log(`  ↻ ${label} (retry ${i + 1})`);
      await new Promise((r) => setTimeout(r, 700 * (i + 1)));
    }
  }
  throw lastErr;
}
