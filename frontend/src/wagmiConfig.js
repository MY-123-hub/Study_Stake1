import { http, createConfig, fallback } from 'wagmi'
import { bsc } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

export const config = createConfig({
  chains: [bsc],
  connectors: [
    injected({ target: 'okxWallet' }),
    injected({ target: 'metaMask' }),
    injected(),
  ],
  transports: {
    [bsc.id]: fallback([
      http('https://binance.llamarpc.com', { batch: true }),
      http('https://rpc.ankr.com/bsc', { retryCount: 2 }),
      http('https://bsc-mainnet.public.blastapi.io', { retryCount: 2 }),
      http('https://bsc-dataseed1.binance.org', { retryCount: 1 }),
    ]),
  },
  ssr: false,
})
