import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { STUDY_STAKE_PROXY, USDC } from '../contracts.js'
import abi from '../abi.json'

export default function DepositWithdraw() {
  const { address, isConnected } = useAccount()
  const [amount, setAmount] = useState('')

  const { data: usdcBalance } = useReadContract({
    address: USDC,
    abi: [
      {
        inputs: [{ name: 'account', type: 'address' }],
        name: 'balanceOf',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: USDC,
    abi: [
      {
        inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }],
        name: 'allowance',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'allowance',
    args: address ? [address, STUDY_STAKE_PROXY] : undefined,
    query: { enabled: !!address },
  })

  const { writeContract: approve, isPending: isApproving, data: approveHash, error: approveError, reset: resetApprove } = useWriteContract()
  const { isLoading: isApprovingConfirming, isSuccess: isApprovedSuccess } = useWaitForTransactionReceipt({
    hash: approveHash, confirmations: 1, pollingInterval: 2000,
  })

  const { writeContract: deposit, isPending: isDepositing, data: depositHash, error: depositError, reset: resetDeposit } = useWriteContract()
  const { isLoading: isDepositConfirming, isSuccess: isDepositSuccess } = useWaitForTransactionReceipt({
    hash: depositHash, confirmations: 1, pollingInterval: 2000,
  })

  const { writeContract: withdraw, isPending: isWithdrawing, data: withdrawHash, error: withdrawError } = useWriteContract()
  const { isLoading: isWithdrawConfirming } = useWaitForTransactionReceipt({
    hash: withdrawHash, confirmations: 1, pollingInterval: 2000,
  })

  if (isApprovedSuccess) {
    refetchAllowance?.()
    resetApprove()
  }

  if (isDepositSuccess) {
    setAmount('')
    resetDeposit()
  }

  if (!isConnected) return null

  const amountWei = amount && Number(amount) > 0 ? parseUnits(amount, 6) : BigInt(0)
  const hasAllowance = allowance !== undefined && BigInt(allowance) >= amountWei
  const hasBalance = usdcBalance !== undefined && BigInt(usdcBalance) >= amountWei
  const canDeposit = hasAllowance && hasBalance && Number(amount) > 0

  const handleApprove = () => {
    if (!amount || Number(amount) <= 0) return
    approve({
      address: USDC,
      abi: [
        {
          inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }],
          name: 'approve',
          outputs: [{ name: '', type: 'bool' }],
          stateMutability: 'nonpayable',
          type: 'function',
        },
      ],
      functionName: 'approve',
      args: [STUDY_STAKE_PROXY, amountWei],
      gas: 60000n,
    })
  }

  const handleDeposit = () => {
    if (!canDeposit) return
    deposit({
      address: STUDY_STAKE_PROXY,
      abi,
      functionName: 'deposit',
      args: [amountWei],
      gas: 150000n,
    })
  }

  const handleWithdraw = () => {
    if (!amount || Number(amount) <= 0) return
    withdraw({
      address: STUDY_STAKE_PROXY,
      abi,
      functionName: 'withdraw',
      args: [amountWei],
      gas: 100000n,
    })
  }

  const balText = usdcBalance !== undefined ? `${Number(formatUnits(usdcBalance, 6)).toFixed(2)} USDC` : '--'

  return (
    <div className="card">
      <h3>存款 / 提现</h3>

      <div className="balance-info">
        <span>USDC 余额</span>
        <span className="balance-value">{balText}</span>
      </div>

      <div className="form-group">
        <label>金额 (USDC)</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="例如: 100"
          min="0"
          step="0.01"
        />
      </div>

      {!hasAllowance && Number(amount) > 0 && (
        <p className="hint warning">需要先授权才能存入</p>
      )}

      <div className="btn-stack">
        {!hasAllowance ? (
          <button
            onClick={handleApprove}
            disabled={isApproving || isApprovingConfirming || !hasBalance || !Number(amount)}
            className="btn btn-primary btn-full"
          >
            {isApproving ? '确认中...' : isApprovingConfirming ? '授权确认中...' : isApprovedSuccess ? '授权成功' : '第 1 步: 授权 USDC'}
          </button>
        ) : (
          <button disabled className="btn btn-full" style={{ background: 'var(--canvas-soft)', color: 'var(--ink-mute)' }}>
            已授权 ({Number(formatUnits(allowance, 6)).toFixed(2)} USDC)
          </button>
        )}

        <button
          onClick={handleDeposit}
          disabled={!canDeposit || isDepositing || isDepositConfirming}
          className="btn btn-primary btn-full"
        >
          {isDepositing ? '确认中...' : isDepositConfirming ? '存入确认中...' : isDepositSuccess ? '存入成功' : '第 2 步: 存入'}
        </button>

        <hr className="divider" />

        <button
          onClick={handleWithdraw}
          disabled={isWithdrawing || isWithdrawConfirming || !Number(amount)}
          className="btn btn-outline btn-full"
        >
          {isWithdrawing || isWithdrawConfirming ? '提现中...' : '提现'}
        </button>
      </div>

      {(approveError && !isApproving) && (
        <p className="error-msg">授权失败: {approveError.shortMessage || approveError.message}</p>
      )}
      {(depositError && !isDepositing) && (
        <p className="error-msg">存入失败: {depositError.shortMessage || depositError.message}</p>
      )}
      {(withdrawError && !isWithdrawing) && (
        <p className="error-msg">提现失败: {withdrawError.shortMessage || withdrawError.message}</p>
      )}
    </div>
  )
}
