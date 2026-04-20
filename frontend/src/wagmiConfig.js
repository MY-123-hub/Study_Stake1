import { http, createConfig, fallback } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

// 多个 RPC 失败自动切换，公共节点不稳定时用备用
export const config = createConfig({
  chains: [sepolia],
  connectors: [
    injected(),
  ],
  transports: {
    [sepolia.id]: fallback([
      http('https://rpc.sepolia.org', { batch: true }),
      http('https://ethereum-sepolia-rpc.publicnode.com', { retryCount: 2 }),
      http('https://rpc.ankr.com/eth_sepolia', { retryCount: 2 }),
      http('https://sepolia.gateway.tenderly.co', { retryCount: 1 }),
    ]),
  },
  ssr: false,
})
