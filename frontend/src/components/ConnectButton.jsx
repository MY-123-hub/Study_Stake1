import { useAccount, useConnect, useDisconnect, useSwitchChain, useChainId } from 'wagmi'
import { bsc } from 'wagmi/chains'

export default function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain, isPending: isSwitching } = useSwitchChain()
  const chainId = useChainId()

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
        <button
          onClick={() => switchChain({ chainId: bsc.id })}
          disabled={isSwitching}
          className="btn btn-small btn-danger"
          style={{ marginRight: 8 }}
        >
          切换到 BSC
        </button>
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
