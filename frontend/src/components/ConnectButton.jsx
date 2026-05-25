import { useAccount, useConnect, useDisconnect } from 'wagmi'

export default function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()

  if (!isConnected) {
    return (
      <button
        onClick={() => connect({ connector: connectors[0] })}
        disabled={isPending}
        className="btn btn-primary"
      >
        {isPending ? '连接中...' : '连接钱包'}
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
