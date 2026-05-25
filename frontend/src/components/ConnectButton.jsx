import { useState, useRef, useEffect } from 'react'
import { useAccount, useConnect, useDisconnect } from 'wagmi'

const WALLET_LABELS = {
  okxWallet: 'OKX Wallet',
  metaMask: 'MetaMask',
  injected: '浏览器钱包',
}

export default function ConnectButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const [showMenu, setShowMenu] = useState(false)
  const menuRef = useRef(null)

  // 点击外部关闭菜单
  useEffect(() => {
    if (!showMenu) return
    const handler = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setShowMenu(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [showMenu])

  if (!isConnected) {
    return (
      <div ref={menuRef} style={{ position: 'relative' }}>
        <button
          onClick={() => setShowMenu(!showMenu)}
          className="btn btn-primary"
        >
          {isPending ? '连接中...' : '连接钱包'}
        </button>
        {showMenu && (
          <div style={{
            position: 'absolute',
            right: 0,
            top: '100%',
            marginTop: 8,
            background: '#fff',
            border: '1px solid #e3e8ee',
            borderRadius: 12,
            boxShadow: '0 8px 24px rgba(0,55,112,0.12), 0 2px 6px rgba(0,55,112,0.06)',
            minWidth: 200,
            zIndex: 100,
            overflow: 'hidden',
          }}>
            {connectors.map((c) => {
              const label = WALLET_LABELS[c.id] || c.name || c.id
              return (
                <button
                  key={c.id}
                  onClick={() => {
                    setShowMenu(false)
                    connect({ connector: c })
                  }}
                  className="btn"
                  style={{
                    width: '100%',
                    justifyContent: 'flex-start',
                    padding: '12px 16px',
                    borderRadius: 0,
                    border: 'none',
                    background: 'transparent',
                    color: '#0d253d',
                    fontSize: 15,
                    fontWeight: 400,
                  }}
                  onMouseOver={(e) => e.target.style.background = '#f6f9fc'}
                  onMouseOut={(e) => e.target.style.background = 'transparent'}
                >
                  {label}
                </button>
              )
            })}
          </div>
        )}
      </div>
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
