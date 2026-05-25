import { useEffect } from 'react'
import { useAccount, useConnect, useDisconnect, useSwitchChain, useChainId } from 'wagmi'
import { bsc } from 'wagmi/chains'

export default function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain, isPending: isSwitching } = useSwitchChain()
  const chainId = useChainId()

  useEffect(() => {
    if (isConnected && chainId !== bsc.id && !isSwitching) {
      switchChain({ chainId: bsc.id })
    }
  }, [isConnected, chainId, isSwitching, switchChain])

  if (!isConnected) {
    if (connectors.length === 0) {
      return (
        <button disabled className="btn btn-outline">
          未检测到钱包插件
        </button>
      )
    }

    if (connectors.length === 1) {
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

    return (
      <div style={{ display: 'flex', gap: 8 }}>
        {connectors.map((c) => (
          <button
            key={c.id}
            onClick={() => connect({ connector: c, chainId: bsc.id })}
            disabled={isPending}
            className="btn btn-primary"
            style={{ fontSize: 13 }}
          >
            {c.name || '连接钱包'}
          </button>
        ))}
      </div>
    )
  }

  const isWrongChain = chainId !== bsc.id

  return (
    <div className="wallet-info">
      {isWrongChain && (
        <span style={{ color: '#dc2626', fontSize: 13, fontWeight: 500, marginRight: 10 }}>
          {isSwitching ? '切换中...' : '请切换到 BNB Chain'}
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
