import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { injected } from 'wagmi/connectors'

export default function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()

  if (!isConnected) {
    return (
      <button
        onClick={() => connect({ connector: connectors[0] })}
        disabled={isPending}
        className="btn btn-outline"
      >
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
            <path d="M7 11V7a5 5 0 0110 0v4"/>
          </svg>
          {isPending ? '连接中...' : '连接钱包'}
        </span>
      </button>
    )
  }

  return (
    <div className="wallet-info">
      <span className="address">
        {address.slice(0, 6)}...{address.slice(-4)}
      </span>
      <button onClick={() => disconnect()} className="btn btn-small btn-outline">
        断开
      </button>
    </div>
  )
}
