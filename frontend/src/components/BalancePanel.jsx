import { useAccount, useReadContract } from 'wagmi'
import { formatUnits } from 'viem'
import { STUDY_STAKE_PROXY } from '../contracts.js'
import abi from '../abi.json'

export default function BalancePanel() {
  const { address, isConnected } = useAccount()

  const { data: balance } = useReadContract({
    address: STUDY_STAKE_PROXY,
    abi,
    functionName: 'balances',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  const { data: available } = useReadContract({
    address: STUDY_STAKE_PROXY,
    abi,
    functionName: 'availableBalance',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  if (!isConnected) return null

  const bal = balance !== undefined ? Number(formatUnits(BigInt(balance), 6)) : 0
  const avail = available !== undefined ? Number(formatUnits(BigInt(available), 6)) : 0

  return (
    <div className="card">
      <h3>余额</h3>
      <div className="balance-grid">
        <div className="balance-item">
          <span className="label">总存款</span>
          <span className="value">{bal.toFixed(2)}</span>
        </div>
        <div className="balance-item">
          <span className="label">可提现</span>
          <span className="value highlight">{avail.toFixed(2)}</span>
        </div>
        <div className="balance-item">
          <span className="label">已锁定</span>
          <span className="value locked">{(bal - avail).toFixed(2)}</span>
        </div>
      </div>
    </div>
  )
}
