import { useState, useEffect, useRef } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { formatUnits } from 'viem'
import { STUDY_STAKE_PROXY } from '../contracts.js'
import abi from '../abi.json'

// Task status mapping
const STATUS_MAP = {
  0: 'Active',
  1: 'Completed',
  2: 'Slashed',
}

const MODE_MAP = {
  0: '🖱️ Click',
  1: '📱 NFC',
}

export default function TaskList({ refreshTrigger }) {
  const { address, isConnected } = useAccount()
  const [activeTab, setActiveTab] = useState('active')

  // Task count
  const { data: taskCount } = useReadContract({
    address: STUDY_STAKE_PROXY,
    abi,
    functionName: 'taskCount',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })

  // We'll fetch tasks by iterating IDs
  const count = taskCount !== undefined ? Number(taskCount) : 0
  const tasks = []
  for (let i = 1; i <= count; i++) {
    tasks.push(
      <TaskItem key={i} taskId={i} user={address} refreshTrigger={refreshTrigger} />
    )
  }

  if (!isConnected) return null

  return (
    <div className="card">
      <h3>📝 我的任务 ({count})</h3>

      {count === 0 && (
        <p className="empty-hint">还没有任务，先创建一个吧 👆</p>
      )}

      {/* Tab 切换 */}
      {count > 0 && (
        <div className="tab-bar">
          <button
            className={`tab ${activeTab === 'active' ? 'active' : ''}`}
            onClick={() => setActiveTab('active')}
          >
            进行中
          </button>
          <button
            className={`tab ${activeTab === 'completed' ? 'active' : ''}`}
            onClick={() => setActiveTab('completed')}
          >
            已完成
          </button>
          <button
            className={`tab ${activeTab === 'slashed' ? 'active' : ''}`}
            onClick={() => setActiveTab('slashed')}
          >
            已违约
          </button>
        </div>
      )}

      <div className="task-list">
        {/* 实际渲染通过 TaskItem 内部控制显示/隐藏 */}
        {tasks}
      </div>
    </div>
  )
}

// 单个任务项组件
function TaskItem({ taskId, user, refreshTrigger }) {
  // Read task data (8 fields: id, user, targetTime, window, penalty, mode, allowedTag, status)
  const { data: task, refetch } = useReadContract({
    address: STUDY_STAKE_PROXY,
    abi,
    functionName: 'tasks',
    args: [user, BigInt(taskId)],
    query: { enabled: !!user },
  })

  // Listen to refresh trigger
  const prevTrigger = useRef(refreshTrigger)
  useEffect(() => {
    if (prevTrigger.current !== refreshTrigger) refetch()
    prevTrigger.current = refreshTrigger
  }, [refreshTrigger])

  if (!task) return null

  const [id, u, targetTime, windowSec, penalty, mode, tagId, status] = task
  const statusNum = Number(status)
  const modeNum = Number(mode)
  const penaltyUsdc = Number(formatUnits(penalty, 6))

  const now = Math.floor(Date.now() / 1000)
  const targetTs = Number(targetTime)
  const winSec = Number(windowSec)

  // Time state calculation
  let timeState = ''
  let timeColor = ''
  if (statusNum === 0) { // Active
    if (now < targetTs - 60) {
      timeState = `⏳ ${formatDuration(targetTs - now)}后开始`
      timeColor = 'pending'
    } else if (now >= targetTs - 60 && now <= targetTs + winSec) {
      timeState = `✅ 可签到（剩余${formatDuration(targetTs + winSec - now)}）`
      timeColor = 'ready'
    } else {
      timeState = `⏰ 已超时，可清算`
      timeColor = 'overdue'
    }
  }

  return (
    <div className={`task-item status-${STATUS_MAP[statusNum].toLowerCase()}`}>
      <div className="task-header">
        <span className="task-id">#{Number(id)}</span>
        <span className="task-mode">{MODE_MAP[modeNum]}</span>
        <span className={`task-status badge-${STATUS_MAP[statusNum].toLowerCase()}`}>
          {STATUS_MAP[statusNum]}
        </span>
      </div>

      <div className="task-details">
        <div className="detail-row">
          <span>目标时间</span>
          <span>{formatDate(targetTs)}</span>
        </div>
        <div className="detail-row">
          <span>窗口期</span>
          <span>{winSec}秒 ({winSec / 60}分钟)</span>
        </div>
        <div className="detail-row">
          <span>惩罚金额</span>
          <span>{penaltyUsdc} USDC</span>
        </div>
        {modeNum === 1 && (
          <div className="detail-row">
            <span>NFC Tag</span>
            <code className="tag-code">{tagId}</code>
          </div>
        )}
        {statusNum === 0 && (
          <div className={`detail-row time-state ${timeColor}`}>
            <span>状态</span>
            <span>{timeState}</span>
          </div>
        )}
      </div>

      {/* 操作按钮 */}
      {statusNum === 0 && (
        <TaskActions
          taskId={taskId}
          user={user}
          mode={modeNum}
          status={statusNum}
          canCheckIn={now >= targetTs - 60 && now <= targetTs + winSec}
          canSlash={now > targetTs + winSec}
          onSuccess={() => refetch()}
        />
      )}
    </div>
  )
}

// 操作按钮组件
function TaskActions({ taskId, user, mode, status, canCheckIn, canSlash, onSuccess }) {
  // Click checkIn
  const { writeContract: writeCheckIn, isPending: ciPending, data: ciHash } = useWriteContract()
  const { isLoading: ciConfirming } = useWaitForTransactionReceipt({ hash: ciHash, confirmations: 1, pollingInterval: 2000 })

  // NFC checkIn
  const { writeContract: writeNfcCheckIn, isPending: nfcPending, data: nfcHash } = useWriteContract()
  const { isLoading: nfcConfirming } = useWaitForTransactionReceipt({ hash: nfcHash, confirmations: 1, pollingInterval: 2000 })
  const [nfcTagId, setNfcTagId] = useState('')

  // Slash
  const { writeContract: writeSlash, isPending: slPending, data: slHash } = useWriteContract()
  const { isLoading: slConfirming } = useWaitForTransactionReceipt({ hash: slHash, confirmations: 1, pollingInterval: 2000 })

  const handleCheckIn = () => {
    if (mode === 1) {
      if (!nfcTagId || nfcTagId === '0x00000000') {
        alert('请输入 NFC Tag ID 或扫描标签')
        return
      }
      writeNfcCheckIn({
        address: STUDY_STAKE_PROXY,
        abi,
        functionName: 'checkInWithNFC',
        args: [BigInt(taskId), nfcTagId.startsWith('0x') ? nfcTagId : `0x${nfcTagId}`],
        gas: 200000n,
      })
    } else {
      writeCheckIn({
        address: STUDY_STAKE_PROXY,
        abi,
        functionName: 'checkIn',
        args: [BigInt(taskId)],
        gas: 100000n,
      })
    }
  }

  return (
    <div className="task-actions">
      {canCheckIn && (
        <div className="action-row">
          {mode === 1 ? (
            <>
              <input
                type="text"
                value={nfcTagId}
                onChange={(e) => setNfcTagId(e.target.value)}
                placeholder="NFC Tag ID"
                className="nfc-tag-input"
                maxLength={10}
              />
              <NfcScanInline onScan={(id) => setNfcTagId(id)} />
              <button
                onClick={handleCheckIn}
                disabled={nfcPending || nfcConfirming}
                className="btn btn-small btn-success"
              >
                {nfcPending || nfcConfirming ? '签到中...' : '📱 NFC 签到'}
              </button>
            </>
          ) : (
            <button
              onClick={handleCheckIn}
              disabled={ciPending || ciConfirming}
              className="btn btn-small btn-success"
            >
              {ciPending || ciConfirming ? '签到中...' : '✅ 点击签到'}
            </button>
          )}
        </div>
      )}

      {canSlash && (
        <button
          onClick={() => writeSlash({
            address: STUDY_STAKE_PROXY,
            abi,
            functionName: 'slash',
            args: [user, BigInt(taskId)],
            gas: 150000n,
          })}
          disabled={slPending || slConfirming}
          className="btn btn-small btn-danger"
        >
          {slPending || slConfirming ? '清算中...' : '⚠️ 违约清算'}
        </button>
      )}

      {!canCheckIn && !canSlash && status === 0 && (
        <span className="waiting">等待到达目标时间...</span>
      )}
    </div>
  )
}

// 行内 NFC 扫描
function NfcScanInline({ onScan }) {
  const handleScan = async () => {
    if ('NDEFReader' in window) {
      try {
        const reader = new window.NDEFReader()
        await reader.scan()
        reader.onreading = (event) => {
          const { serialNumber } = event.message.records[0]
          const hex = serialNumber.replace(/[^0-9a-fA-F]/g, '')
          const id = '0x' + hex.slice(-8).toUpperCase().padStart(8, '0')
          onScan(id)
        }
      } catch (err) {
        alert(err.name === 'NotAllowedError' ? '需要授权 NFC' : err.message)
      }
    } else {
      alert('浏览器不支持 Web NFC')
    }
  }

  return (
    <button type="button" onClick={handleScan} className="btn btn-tiny btn-nfc">
      📡
    </button>
  )
}

// 工具函数
function formatDuration(seconds) {
  if (seconds < 60) return `${seconds}秒`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}分钟`
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  return `${h}小时${m > 0 ? m + '分' : ''}`
}

function formatDate(timestamp) {
  return new Date(timestamp * 1000).toLocaleString('zh-CN', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}
