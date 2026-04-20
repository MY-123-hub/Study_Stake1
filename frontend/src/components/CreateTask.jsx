import { useState } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'
import { STUDY_STAKE_PROXY } from '../contracts.js'
import abi from '../abi.json'

// 模式枚举
const MODES = {
  Click: 0,
  NFC: 1,
}

export default function CreateTask({ onTaskCreated }) {
  const { isConnected } = useAccount()
  const [mode, setMode] = useState('Click')
  const [targetTime, setTargetTime] = useState('')
  const [window, setWindow] = useState('1800') // 默认30分钟
  const [penalty, setPenalty] = useState('')
  const [tagId, setTagId] = useState('')

  const { writeContract, data: hash, isPending, error, reset } = useWriteContract()
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
    confirmations: 1, // Sepolia 只需 1 个确认就够了
    pollingInterval: 2000, // 每 2 秒查一次
  })

  const handleSubmit = (e) => {
    e.preventDefault()

    if (!targetTime || !penalty) return

    const targetTs = Math.floor(new Date(targetTime).getTime() / 1000)
    const windowSec = parseInt(window) || 1800
    const penaltyWei = parseUnits(penalty, 6)

    if (mode === 'NFC') {
      if (!tagId || tagId === '0x00000000') {
        alert('NFC 模式需要输入有效的 Tag ID')
        return
      }
      writeContract({
        address: STUDY_STAKE_PROXY,
        abi,
        functionName: 'createTask',
        args: [
          BigInt(targetTs),
          BigInt(windowSec),
          penaltyWei,
          MODES.NFC,
          tagId.startsWith('0x') ? tagId : `0x${tagId}`,
        ],
        gas: 300000n,
      })
    } else {
      writeContract({
        address: STUDY_STAKE_PROXY,
        abi,
        functionName: 'createSimpleTask',
        args: [BigInt(targetTs), BigInt(windowSec), penaltyWei],
        gas: 250000n,
      })
    }

    if (onTaskCreated) onTaskCreated()
  }

  if (!isConnected) return null

  return (
    <div className="card">
      <h3>📋 创建任务</h3>
      <form onSubmit={handleSubmit} className="task-form">

        {/* 模式选择 */}
        <div className="form-group">
          <label>签到方式</label>
          <div className="mode-toggle">
            <button
              type="button"
              className={mode === 'Click' ? 'btn btn-mode active' : 'btn btn-mode'}
              onClick={() => setMode('Click')}
            >
              🖱️ 点击签到
            </button>
            <button
              type="button"
              className={mode === 'NFC' ? 'btn btn-mode active' : 'btn btn-mode'}
              onClick={() => setMode('NFC')}
            >
              📱 NFC 签到
            </button>
          </div>
        </div>

        {/* 目标时间 */}
        <div className="form-group">
          <label>目标时间（必须是未来）</label>
          <input
            type="datetime-local"
            value={targetTime}
            onChange={(e) => setTargetTime(e.target.value)}
            min={new Date(Date.now() + 60000).toISOString().slice(0, 16)}
          />
        </div>

        {/* 窗口期 */}
        <div className="form-group">
          <label>窗口期（秒）</label>
          <select value={window} onChange={(e) => setWindow(e.target.value)}>
            <option value="900">15 分钟</option>
            <option value="1800">30 分钟</option>
            <option value="3600">1 小时</option>
            <option value="7200">2 小时</option>
          </select>
        </div>

        {/* 惩罚金额 */}
        <div className="form-group">
          <label>惩罚金额 (USDC)</label>
          <input
            type="number"
            value={penalty}
            onChange={(e) => setPenalty(e.target.value)}
            placeholder="例如: 20"
            min="0"
            step="0.01"
          />
        </div>

        {/* NFC Tag ID — 仅 NFC 模式显示 */}
        {mode === 'NFC' && (
          <div className="form-group nfc-field">
            <label>NFC 标签 ID</label>
            <div className="nfc-input-row">
              <input
                type="text"
                value={tagId}
                onChange={(e) => setTagId(e.target.value)}
                placeholder="例如: A1B2C3D4 或 0xA1B2C3D4"
                maxLength={10}
              />
              <NfcScanButton onScan={(id) => setTagId(id)} />
            </div>
            <p className="hint">📱 点击右侧按钮用手机扫描 NFC 标签自动填入</p>
          </div>
        )}

        {/* 提交 */}
        <button
          type="submit"
          disabled={isPending || isConfirming || !targetTime || !penalty}
          className="btn btn-primary btn-full"
        >
          {isPending ? '确认中钱包...' : isConfirming ? '⏳ 等待区块确认...' : isConfirmed ? '✅ 创建成功！' : `✅ 创建${mode}任务`}
        </button>

        {error && (
          <p className="error-msg">{error.message?.includes('user rejected') ? '用户取消了交易' : error.shortMessage || error.message}</p>
        )}
      </form>
    </div>
  )
}

// Web NFC 扫描按钮组件
function NfcScanButton({ onScan }) {
  const [scanning, setScanning] = useState(false)
  const [supported, setSupported] = useState(true)
  const [errorMsg, setErrorMsg] = useState('')

  const handleScan = async () => {
    setErrorMsg('')
    if ('NDEFReader' in window) {
      try {
        setScanning(true)
        const reader = new window.NDEFReader()
        await reader.scan()
        reader.onreading = (event) => {
          const { serialNumber } = event.message.records[0]
          // 取最后4字节作为 bytes4 tagId
          const hex = serialNumber.replace(/[^0-9a-fA-F]/g, '')
          const tagId = '0x' + hex.slice(-8).toUpperCase().padStart(8, '0')
          onScan(tagId)
          setScanning(false)
        }
        reader.onreadingerror = () => {
          setErrorMsg('NFC 读取失败，请重试')
          setScanning(false)
        }
        // 超时处理
        setTimeout(() => {
          setScanning(false)
          if (scanning) setErrorMsg('扫描超时，请再试一次')
        }, 30000)
      } catch (err) {
        setErrorMsg(err.name === 'NotAllowedError' ? '需要授权才能使用 NFC' : err.message)
        setScanning(false)
      }
    } else {
      setSupported(false)
      setErrorMsg('你的浏览器不支持 Web NFC（需要 Android Chrome 或 Safari）')
    }
  }

  if (!supported && errorMsg) {
    return <span className="hint error">{errorMsg}</span>
  }

  return (
    <button
      type="button"
      onClick={handleScan}
      disabled={scanning}
      className={`btn btn-small ${scanning ? 'btn-scanning' : 'btn-nfc'}`}
    >
      {scanning ? '🔄 扫描中...' : '📡 扫描 NFC'}
    </button>
  )
}
