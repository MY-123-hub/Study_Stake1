import { useEffect } from 'react'
import { useAccount, useConnect, useDisconnect, useSwitchChain, useChainId } from 'wagmi'
import { bsc } from 'wagmi/chains'

export default function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain, isPending: isSwitching } = useSwitchChain()
  const chainId = useChainId()

  // 连接后如果不在 BSC，自动切换
  useEffect(() => {
    if (isConnected && chainId !== bsc.id) {
      switchChain({ chainId: bsc.id })
    }
  }, [isConnected, chainId])

  if (!isConnected) {
    return (
      <button
        onClick={() => connect({ connector: connectors[0], chainId: bsc.id })}
        disabled={isPending}
        className="btn btn-primary"
      >
        {isPending ? '连接中...' : '连接钱包'}
      </button>
    )
  }

  const isWrongChain = chainId !== bsc.id

  return (
    <div className="wallet-info">
      {isWrongChain && (
        <span style={{ color: '#dc2626', fontSize: 13, fontWeight: 500 }}>
          {isSwitching ? '切换网络中...' : '请先在钱包中切换到 BNB Chain'}
        </span>
      )}
      <span className="address">
        {address.slice(0, 6)}...{address.slice(-4)}
      </span>
      <button onClick={() => disconnect()} className="btn btn-small btn-outline">
        断开
      </button>
    </div>
  )
}
